// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation
import SwiftData

// MARK: - DocumentViewModel

/// Manages state for the Document view: loading the rendered document, person/gloss
/// lookup tables, and research-note cross-project indicator.
///
/// ## Loading Sequence
/// 1. `load()` is called on appear with the volume URL.
/// 2. Parses the document AST and persons/terms in parallel.
/// 3. Converts the AST to a `FRUSDocumentRenderModel` with person/gloss lookup closures.
/// 4. `recordReadingHistory()` inserts a `ReadingHistoryEntry` into SwiftData.
///
/// ## persName / gloss Sheets
/// `selectedPerson` and `selectedGloss` are set by the renderer callbacks and drive
/// sheet presentation. Cross-reference navigation appends a new `.document` level to
/// `BrowserViewModel.navigationPath`.
///
/// ## Summarization
/// `generateSummary(prompt:provider:service:activeProjectId:context:)` builds a
/// `SummarizationPromptSnapshot` on the main actor (safe for `@Model` access), then
/// calls `SummarizationService.summarize` across the actor boundary.
/// `documentPlainText` is populated during `load()` from `FRUSASTNode.plainText`.
///
/// Version history:
///   1.0 — Session 12: initial implementation
///   1.1 — Session 20: add documentPlainText, isSummarizing, showSummarizeSheet, generateSummary
///   1.2 — Session 40: personMentionStore dependency; selectedPersonMentionCount; loadPersonMentionCount
///   1.3 — Session 41: persons/terms resolved from SQLite first; XML parse kept as fallback
///   1.4 — Session 149: `DocumentSheet.personNotFound`/`glossNotFound` cases added; both iOS
///          and macOS document views now surface a user-facing message when the person/gloss
///          lookup returns nil, instead of silently doing nothing
///   1.4 — Session 66: `documentTitle` stored property added; set from first `<head>` element
///          after load so cross-reference targets (created with `header: ""`) can supply
///          a meaningful navigation title once the document has been parsed
///   1.5 — Session 155: `bibtexCitation`, `risCitation`, `zoteroItem(tags:notes:)` added for
///          the citation Export menu's "Send to Zotero" actions
///   1.6 — Session 2026-07-03 (people-eval finding G): `selectedPersonRollupId` keeps the
///          rollup resolved by `loadPersonMentionCount`, so "Find all mentions" can search
///          the cross-corpus rollup identity (the same count the sheet displays) instead of
///          the raw per-volume `ref` string, which collides across volumes
///   1.7 — Source Explorer Phase 1 (Session 2026-07-03): the file's `extractSourceNote`
///          free function now delegates to `IndexingPipeline.extractSourceNote(from:)`,
///          the canonical frus-sources locator chain, so the document Source sheet shows
///          the same note the index stores. Display changes with it: head-nested notes
///          found first (with the dual-encoding gate deferring non-`Source:`-prefixed
///          head remarks to top-level citations), `[Source: …]` wrapper stripped,
///          interior whitespace collapsed, e-volume summary segs excluded
///   Session 09: subject-tag loading removed with the document-level taxonomy
///         (`subjectTags` property and the `subjectTagStore` init dependency are gone).
@Observable
@MainActor
public final class DocumentViewModel {

    // MARK: - Document State

    /// The fully-rendered model, set after a successful load.
    public var renderModel: FRUSDocumentRenderModel?

    /// Plain-text document title extracted from the first `<head>` element, set
    /// after a successful load.  Used as the navigation title when the
    /// `DocumentBrowserEntry` was created without a header (e.g. cross-reference
    /// targets, which are constructed with `header: ""` because the title is not
    /// known until the XML is parsed).
    public var documentTitle: String?

    /// Canonical document number resolved from the parsed document (the div's `@n` — the
    /// history.state.gov document number — falling back to the `<head>` leading number).
    /// Set during `load`.
    ///
    /// Used by `formattedCitation` in preference to `entry.documentNumber`, which is `nil`
    /// when the document was opened via a path that doesn't carry the number (e.g. a
    /// cross-reference tap) — that was leaving some shared citations without a document
    /// number.
    public var resolvedDocumentNumber: String?

    /// `true` while the document is being parsed/converted.
    public var isLoading: Bool = false

    /// Non-nil if loading failed.
    public var loadError: Error? = nil

    // MARK: - Person / Gloss Lookup Tables

    /// Persons from the volume's `<listPerson>`, indexed by `ref` attribute.
    public var personsByRef: [String: PersonEntry] = [:]

    /// Glossary terms from the volume's `<glossary>`, indexed by `ref` attribute.
    public var termsByRef: [String: GlossEntry] = [:]

    // MARK: - Sheet State

    /// Person selected via a `<persName>` tap; drives the List of Persons sheet.
    public var selectedPerson: PersonEntry? = nil

    /// Gloss entry selected via a `<gloss>` tap; drives the Terms sheet.
    public var selectedGloss: GlossEntry? = nil

    /// Count of indexed documents that mention the currently-selected person.
    /// Set to 0 when no person is selected or when `personMentionStore` is nil.
    public var selectedPersonMentionCount: Int = 0

    /// The cross-corpus rollup id resolved for the currently-selected person by
    /// `loadPersonMentionCount`, or `nil` when the rollup hasn't been built or has no row for
    /// this `(volume, ref)`. "Find all mentions" passes this to the search so results match
    /// the displayed cross-corpus count — the raw per-volume `ref` string is shared by
    /// unrelated people across volumes (people-eval finding G).
    public var selectedPersonRollupId: Int? = nil

    // MARK: - Research Note Indicator

    /// Count of research notes attached to this document that belong to a
    /// project OTHER than the currently active project.
    public var crossProjectNoteCount: Int = 0

    /// The actual notes counted above, stored for cross-project reveal UI.
    var crossProjectNotes: [ResearchNote] = []

    // MARK: - Volume Navigation

    /// The document immediately before this one in the volume's document order,
    /// or `nil` if this is the first document. Populated by `loadAdjacentEntries`.
    /// Drives `MacDocumentView`'s prev/next chevron buttons and `DocumentView`'s
    /// edge-tap "previous document" gesture in Read mode.
    public var previousEntry: DocumentBrowserEntry? = nil

    /// The document immediately after this one in the volume's document order,
    /// or `nil` if this is the last document. Populated by `loadAdjacentEntries`.
    public var nextEntry: DocumentBrowserEntry? = nil

    // MARK: - Summaries

    /// Summaries for this document, ordered newest-first.
    var summaries: [GeneratedSummary] = []

    /// Index of the summary currently displayed (0 = most recent).
    public var activeSummaryIndex: Int = 0

    var activeSummary: GeneratedSummary? {
        guard !summaries.isEmpty, summaries.indices.contains(activeSummaryIndex) else { return nil }
        return summaries[activeSummaryIndex]
    }

    // MARK: - Summarization

    /// Plain text of the document body, set during `load()`. Used as input to `SummarizationService`.
    public var documentPlainText: String = ""

    /// `true` while a summarization request is in flight.
    public var isSummarizing: Bool = false

    /// Human-readable description of the most recent summarization failure, or
    /// `nil` when the last attempt succeeded (or none has run). Set by
    /// `generateSummary`; cleared at the start of each new attempt. Displayed as
    /// an alert on iOS and inline in the macOS summary block.
    public var summarizationError: String? = nil

    // MARK: - Source Explorer

    /// Raw plain-text source note extracted during `load()`. `nil` if the document has no source note.
    public var sourceNote: String? = nil

    // MARK: - Citation

    /// Publication year extracted live from the volume's TEI `<publicationStmt><date>`,
    /// populated by `loadPublicationYear(from:)`. Preferred over the bundled
    /// manifest's `publicationDate`, which may hold a coverage range (e.g.
    /// "1969–1976") rather than the volume's actual print year — the same
    /// "indexed coverage range as publication year" bug fixed for the macOS
    /// citation popover in commit e67bed9 (Session 2026-06-07 port to iOS).
    public var parsedPublicationYear: String? = nil

    /// The formatted citation string, available when a volume entry was supplied at init.
    ///
    /// Uses the user's persisted `CitationStyle.current` preference (history.state.gov
    /// by default; Chicago and Turabian also available — see Settings → Display).
    /// Uses `parsedPublicationYear` (live-parsed from the volume XML) in place of
    /// the manifest's `publicationDate` when available — see `loadPublicationYear(from:)`.
    ///
    /// The returned string contains Markdown italic markers (`_..._` or `*...*`)
    /// for the series/volume title. Use `plainTextFormattedCitation` for the
    /// clipboard and share sheet.
    public var formattedCitation: String? {
        guard let volumeEntry else { return nil }
        let docMeta = FRUSDocumentMetadata(
            documentId: entry.documentId,
            documentNumber: resolvedDocumentNumber ?? entry.documentNumber,
            header: entry.header,
            dateline: entry.dateline
        )
        var volMeta = FRUSVolumeMetadata(volumeEntry)
        if let liveYear = parsedPublicationYear {
            volMeta = volMeta.overridingPublicationYear(liveYear)
        }
        return CitationStyle.current.makeFormatter().format(document: docMeta, volume: volMeta)
    }

    /// Plain-text version of `formattedCitation` with Markdown italic markers stripped.
    ///
    /// Citation formatters wrap the title in `_..._` (history.state.gov) or
    /// `*...*` (Chicago/Turabian) for Markdown italics. The clipboard and share
    /// sheet should receive clean text without raw delimiter characters.
    /// `AttributedString.characters` extracts the character sequence after
    /// Markdown parsing, giving plain text automatically.
    public var plainTextFormattedCitation: String? {
        guard let citation = formattedCitation else { return nil }
        if let attrStr = try? AttributedString(
            markdown: citation,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return String(attrStr.characters)
        }
        // Fallback: strip paired delimiters via regex if markdown parsing fails.
        return citation
            .replacingOccurrences(of: #"_([^_]+)_"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
    }

    /// The canonical `history.state.gov` URL for this document.
    ///
    /// Shared by the citation share-sheet action and (in spirit) the same
    /// `historicaldocuments/{volumeId}/{documentId}` convention used by the
    /// macOS `CitationPopoverView`, `CollectionEditorView`, and the citation
    /// exporters (BibTeX/RIS).
    public var canonicalDocumentURL: URL? {
        URL(string: "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)")
    }

    /// A formatted citation plus its canonical URL, suitable for sharing via
    /// the system share sheet (Messages, Mail, etc.). `nil` until both the
    /// citation and canonical URL are available. Uses `plainTextFormattedCitation`
    /// so Markdown italic markers (`_..._`) do not appear as raw underscores in
    /// the share payload.
    public var shareableCitationMessage: String? {
        guard let citation = plainTextFormattedCitation,
              let url = canonicalDocumentURL else { return nil }
        return "\(citation)\n\n\(url.absoluteString)"
    }

    /// The document's citation formatted as a BibTeX `@incollection` record,
    /// for "Copy BibTeX" and "Send to Zotero (BibTeX)…" actions. `nil` until a
    /// volume entry is available.
    public var bibtexCitation: String? {
        guard let volumeEntry else { return nil }
        let docMeta = FRUSDocumentMetadata(entry)
        let volMeta = effectiveVolumeMetadata(volumeEntry)
        return BibtexExporter().export(
            volumeId: entry.volumeId,
            document: docMeta,
            volume: volMeta,
            year: effectivePublicationYear(volMeta: volMeta),
            url: canonicalDocumentURL?.absoluteString
        )
    }

    /// The document's citation formatted as a RIS record, for "Copy RIS".
    /// `nil` until a volume entry is available.
    public var risCitation: String? {
        guard let volumeEntry else { return nil }
        let docMeta = FRUSDocumentMetadata(entry)
        let volMeta = effectiveVolumeMetadata(volumeEntry)
        return RISExporter().export(
            document: docMeta,
            volume: volMeta,
            year: effectivePublicationYear(volMeta: volMeta),
            url: canonicalDocumentURL?.absoluteString
        )
    }

    /// Builds a Zotero JSON `bookSection` item for this document, attaching
    /// the supplied `tags` and `notes` (typically resolved via
    /// `ZoteroJSONExporter.fetchTagsAndNotes`). `nil` until a volume entry is
    /// available.
    public func zoteroItem(tags: [String], notes: [String]) -> ZoteroJSONExporter.Item? {
        guard let volumeEntry else { return nil }
        let docMeta = FRUSDocumentMetadata(entry)
        let volMeta = effectiveVolumeMetadata(volumeEntry)
        return ZoteroJSONExporter.makeItem(
            document: docMeta,
            volume: volMeta,
            year: effectivePublicationYear(volMeta: volMeta),
            url: canonicalDocumentURL?.absoluteString,
            isEditorialNote: entry.isEditorialNote,
            tags: tags,
            notes: notes
        )
    }

    /// Returns `volumeEntry`'s metadata with the publication year overridden by
    /// `parsedPublicationYear` when available — see `formattedCitation`.
    private func effectiveVolumeMetadata(_ volumeEntry: VolumeManifestEntry) -> FRUSVolumeMetadata {
        var volMeta = FRUSVolumeMetadata(volumeEntry)
        if let liveYear = parsedPublicationYear {
            volMeta = volMeta.overridingPublicationYear(liveYear)
        }
        return volMeta
    }

    /// Extracts a display year from `volMeta.publicationDate`, falling back to "n.d.".
    private func effectivePublicationYear(volMeta: FRUSVolumeMetadata) -> String {
        FRUSVolumeMetadata.firstYear(in: volMeta.publicationDate).map(String.init) ?? "n.d."
    }

    /// Reads the volume's downloaded TEI XML and extracts the live publication
    /// year into `parsedPublicationYear`, so `formattedCitation` can prefer it
    /// over the manifest's (possibly coverage-range) `publicationDate`.
    ///
    /// Mirrors `CitationPopoverView.loadPublicationYear` on macOS (added in
    /// commit e67bed9 to fix citations showing a document's coverage-range
    /// start year, e.g. "1969", instead of the volume's actual print year,
    /// e.g. "2010"). Idempotent — a no-op once a year has been parsed.
    public func loadPublicationYear(from volumeURL: URL) async {
        guard parsedPublicationYear == nil else { return }
        parsedPublicationYear = await Self.extractPublicationYear(from: volumeURL)
    }

    /// Reads the first 8 KB of `url` (always covers the `teiHeader`) and
    /// extracts the publication year from `<publicationStmt><date @when>` —
    /// the authoritative ISO publication date — falling back to the element's
    /// bare text content (e.g. `<date>2010</date>`).
    private static func extractPublicationYear(from url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            guard let stream = InputStream(url: url) else { return nil }
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 8_192)
            let n = stream.read(&buffer, maxLength: buffer.count)
            guard n > 0,
                  let text = String(bytes: Array(buffer[0..<n]), encoding: .utf8) else { return nil }

            guard let blockStart = text.range(of: "<publicationStmt"),
                  let blockEnd   = text.range(of: "</publicationStmt>"),
                  blockStart.lowerBound < blockEnd.lowerBound else { return nil }
            let block = String(text[blockStart.lowerBound..<blockEnd.upperBound])

            // Prefer @when="YYYY" — most authoritative, always the actual publication year.
            if let yr = regexFirstCapture(#"when="(\d{4})""#, in: block),
               let y = Int(yr), y > 1750, y < 2100 { return yr }
            // Fall back to bare year as text content, e.g. <date>2010</date>.
            if let yr = regexFirstCapture(#">(\d{4})\s*<"#, in: block),
               let y = Int(yr), y > 1750, y < 2100 { return yr }
            return nil
        }.value
    }

    /// Returns the first capture group of `pattern`'s first match in `text`, or `nil`.
    private nonisolated static func regexFirstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text,
                                           range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    // MARK: - Dependencies

    public let entry: DocumentBrowserEntry
    /// Volume manifest entry used for citation generation. `nil` when not found in manifest.
    public let volumeEntry: VolumeManifestEntry?
    private let parser: FRUSDocumentParser
    /// Person mention store for "Find all mentions" feature. Optional — `nil` if the
    /// database could not be opened at boot or in test contexts that don't need it.
    private let personMentionStore: PersonMentionStore?
    /// Shared AST window cache. When supplied, `load(volumeURL:)` serves the
    /// document from memory if a previous parse already produced it (adjacent
    /// page-turns, re-opens) and warms the cache with the parse window otherwise.
    /// `nil` (tests, previews) falls back to plain single-document parsing.
    private let astCache: DocumentASTCache?

    // MARK: - Init

    public init(
        entry: DocumentBrowserEntry,
        volumeEntry: VolumeManifestEntry?,
        parser: FRUSDocumentParser,
        personMentionStore: PersonMentionStore? = nil,
        astCache: DocumentASTCache? = nil
    ) {
        self.entry = entry
        self.volumeEntry = volumeEntry
        self.parser = parser
        self.personMentionStore = personMentionStore
        self.astCache = astCache
    }

    // MARK: - Loading

    /// Parses the document, populates lookup tables, converts to a render model,
    /// and fetches subject tags. Idempotent if already loaded.
    public func load(volumeURL: URL) async {
        guard renderModel == nil else { return }
        isLoading = true
        loadError = nil
        do {
            // Resolve the document AST concurrently with the SQLite glossary lookup.
            // Cache first: a previous parse window (adjacent document, re-open) makes
            // this instant. On a miss, parse a window — the target plus everything
            // before it that the SAX pass produces anyway, plus one trailing document
            // — and warm the cache with the window's tail so Read-mode page-turns in
            // either direction skip the XML entirely.
            async let astResult: FRUSDocumentAST? = { [parser, astCache, entry] in
                if let cached = await astCache?.ast(volumeId: entry.volumeId,
                                                    documentId: entry.documentId) {
                    return cached
                }
                guard let astCache else {
                    return try await parser.parseDocument(documentId: entry.documentId,
                                                          volumeURL: volumeURL)
                }
                let window = try await parser.parseDocumentWindow(
                    documentId: entry.documentId,
                    volumeURL: volumeURL,
                    trailingDocuments: 1
                )
                // Cache the tail of the window (a few documents before the target,
                // the target, and the trailing document) — not the entire prefix.
                await astCache.store(Array(window.suffix(8)), volumeId: entry.volumeId)
                return window.first { $0.documentId == entry.documentId }
            }()

            // SQLite-first persons lookup
            let persons: [PersonEntry]
            let sqlPersons = (try? await personMentionStore?.allPersons(forVolumeId: entry.volumeId)) ?? []
            if sqlPersons.isEmpty {
                persons = (try? await parser.parsePersons(volumeURL: volumeURL)) ?? []
            } else {
                persons = sqlPersons
            }

            // SQLite-first terms lookup
            let terms: [GlossEntry]
            let sqlTerms = (try? await personMentionStore?.allTerms(forVolumeId: entry.volumeId)) ?? []
            if sqlTerms.isEmpty {
                terms = (try? await parser.parseTerms(volumeURL: volumeURL)) ?? []
            } else {
                terms = sqlTerms
            }

            guard let ast = try await astResult else {
                loadError = DocumentLoadError.documentNotFound(entry.documentId)
                isLoading = false
                return
            }

            // Build lookup tables
            var pByRef: [String: PersonEntry] = [:]
            for p in persons { pByRef[p.ref] = p }
            var tByRef:  [String: GlossEntry] = [:]
            var tByText: [String: GlossEntry] = [:]
            for t in terms {
                tByRef[t.ref]              = t
                tByText[t.term.lowercased()] = t
            }
            personsByRef = pByRef
            termsByRef   = tByRef

            // Extract document title from the first <head> element.
            // Needed when this DocumentView was created via a cross-reference
            // (entry.header == "") and must show a meaningful navigation title.
            for node in ast.nodes {
                if case .head(let c) = node {
                    let t = c.map(\.plainText).joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { documentTitle = t }
                    break
                }
            }

            // Resolve the canonical document number from the parsed document (the div's
            // `@n` — the history.state.gov number — with the head-text heuristic as
            // fallback) so the citation carries it regardless of how this document was
            // opened (a cross-reference tap, say, builds the entry without it).
            resolvedDocumentNumber = ast.printedNumber
                ?? IndexingPipeline.extractDocumentNumber(from: ast.nodes)

            // Store plain text for summarization before converting to render model
            documentPlainText = ast.nodes
                .map(\.plainText)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n\n")

            // Extract source note for Source Explorer
            sourceNote = extractSourceNote(from: ast.nodes)

            // Convert AST → render model with lookup closures.
            // `abbrLookup` matches `<abbr>` element text against the glossary by term
            // name (case-insensitive) so abbreviations without an explicit @ref still
            // render as tappable dotted-underline links.
            var converter = ASTToRenderNodeConverter(
                personLookup: { [pByRef] ref in pByRef[ref] },
                glossLookup:  { [tByRef] ref in tByRef[ref] },
                abbrLookup:   { [tByText] text in tByText[text.lowercased()] },
                // Degrade dead cross-references (issue #240). Volume-scoped: brokenness is
                // independent of the source document, so front/back-matter refs resolve too.
                brokenRefLookup: { [vol = entry.volumeId] target in
                    BrokenRefsIndexStore.shared?.degradableInfo(sourceVolume: vol, rawTarget: target)
                }
            )
            renderModel = converter.convert(ast)

            #if DEBUG
            print("[DocumentView] Loaded \(entry.volumeId)/\(entry.documentId) " +
                  "bodyNodes=\(renderModel?.bodyNodes.count ?? 0)")
            #endif
        } catch {
            loadError = error
            #if DEBUG
            print("[DocumentView] Load failed for \(entry.documentId): \(error)")
            #endif
        }
        isLoading = false
    }

    // MARK: - Reading History

    /// Inserts a `ReadingHistoryEntry` into the SwiftData context.
    /// Call this once after a successful load, passing the active project ID.
    ///
    /// **Honours the research-logging preference.** Until Wave R-1 this writer had no gate of
    /// any kind, so "Log Research Sessions" stopped the `SessionEvent` recorder that only the
    /// session log reads while this one — which feeds the History window, Project Home's
    /// recents, Project Leads' engaged documents, the search checklist and the storage hub's
    /// last-opened dates — kept running. A user who turned the switch off had not stopped the
    /// app remembering what they read. It now returns without inserting when logging is off.
    ///
    /// - Parameters:
    ///   - projectId: The active project, stamped onto the entry; `nil` when none is active.
    ///   - context: The context the entry is inserted into.
    ///   - defaults: The store the research-logging gate is read from. Defaults to
    ///     `.standard`; overridden only by tests.
    public func recordReadingHistory(projectId: UUID?,
                                     in context: ModelContext,
                                     defaults: UserDefaults = .standard) {
        guard AppState.isResearchLoggingEnabled(in: defaults) else {
            #if DEBUG
            print("[DocumentView] ReadingHistoryEntry suppressed (research logging off): " +
                  "\(entry.volumeId)/\(entry.documentId)")
            #endif
            return
        }
        let record = ReadingHistoryEntry(
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            displayTitle: entry.header.isEmpty ? nil : entry.header,
            projectId: projectId
        )
        context.insert(record)
        #if DEBUG
        print("[DocumentView] ReadingHistoryEntry recorded: \(entry.volumeId)/\(entry.documentId)")
        #endif
    }

    // MARK: - Cross-Project Notes

    /// Refreshes `crossProjectNoteCount` from SwiftData.
    ///
    /// A note is "cross-project" if it is attached to this document and does NOT
    /// include the current active project in its `projectIds` list.
    public func refreshCrossProjectNoteCount(activeProjectId: UUID?, context: ModelContext) {
        let docId = entry.documentId
        let volId = entry.volumeId
        let descriptor = FetchDescriptor<ResearchNote>(
            predicate: #Predicate { note in
                note.documentId == docId && note.volumeId == volId
            }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        if let pid = activeProjectId {
            let foreign = all.filter { !$0.projectIds.contains(pid) }
            crossProjectNoteCount = foreign.count
            crossProjectNotes = foreign
        } else {
            crossProjectNoteCount = 0
            crossProjectNotes = []
        }
    }

    // MARK: - Volume Navigation

    /// Looks up this document's neighbors within its volume's document order and
    /// populates `previousEntry`/`nextEntry`.
    ///
    /// Mirrors `MacDocumentView.loadDocument()`'s `prevEntry`/`nextEntry` population
    /// (queries `IndexingPipeline.readingSequence(forVolume:)`, which returns the whole
    /// volume — front matter, body, and back matter — in source order, and locates this
    /// document's index). Both platforms then navigate by appending the adjacent entry
    /// to their respective navigation stacks — macOS via bordered chevron buttons, iOS
    /// additionally via the edge-tap "page-turn" gesture in Read mode
    /// (`DocumentView.documentEdgeNavigationOverlay`).
    ///
    /// No-op if `pipeline` is `nil` or the volume has not been indexed — `previousEntry`
    /// and `nextEntry` simply remain `nil`, and dependent UI hides itself accordingly.
    ///
    /// Version history:
    ///   1.0 — Session 2026-06-07: introduced alongside DocumentView's edge-tap
    ///         previous/next document navigation (iOS Read-mode "page-turn" gesture)
    public func loadAdjacentEntries(pipeline: IndexingPipeline?) async {
        guard let pipeline else { return }
        if let docs = try? await pipeline.readingSequence(forVolume: entry.volumeId),
           let idx = docs.firstIndex(where: { $0.documentId == entry.documentId }) {
            previousEntry = idx > 0 ? docs[idx - 1] : nil
            nextEntry = idx + 1 < docs.count ? docs[idx + 1] : nil
        }
    }

    // MARK: - Summaries

    /// Loads summaries for this document from SwiftData, ordered newest-first.
    public func loadSummaries(context: ModelContext) {
        let docId = entry.documentId
        let volId = entry.volumeId
        var descriptor = FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { s in
                // Dedicated headnote drafts (Composer redesign) belong to a collection entry's
                // headnote, not the document's summary carousel.
                s.documentId == docId && s.volumeId == volId && !s.isHeadnoteDraft
            }
        )
        descriptor.fetchLimit = 20
        summaries = ((try? context.fetch(descriptor)) ?? [])
            .sorted { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }
        activeSummaryIndex = 0
    }

    /// Generates a summary for the current document using the given prompt and provider.
    ///
    /// Creates a `SummarizationPromptSnapshot` on the main actor before crossing into
    /// the `SummarizationService` actor, satisfying Swift 6 Sendable requirements.
    /// Reloads `summaries` and resets `activeSummaryIndex` to 0 on completion.
    func generateSummary(
        prompt: SummarizationPrompt,
        provider: any SummarizationProvider,
        service: SummarizationService,
        activeProjectId: UUID?,
        context: ModelContext
    ) async {
        guard !documentPlainText.isEmpty, !isSummarizing else { return }
        isSummarizing = true
        summarizationError = nil

        // Build snapshot on main actor before crossing actor boundary
        let snapshot = SummarizationPromptSnapshot(from: prompt)

        do {
            try await service.summarizeDiscarding(
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                documentText: documentPlainText,
                prompt: snapshot,
                provider: provider,
                activeProjectId: activeProjectId
            )
            loadSummaries(context: context)
            #if DEBUG
            print("[SummarizationUI] Summary generated for \(entry.volumeId)/\(entry.documentId)")
            #endif
        } catch {
            // Surface the failure to the UI — a guardrail rejection, model-busy
            // condition, or oversized document previously looked like "the spinner
            // stopped and nothing happened".
            summarizationError = error.localizedDescription
            #if DEBUG
            print("[SummarizationUI] Generation failed for \(entry.documentId): \(error)")
            #endif
        }

        isSummarizing = false
    }

    // MARK: - Person Mention Count

    /// Fetches and stores the number of indexed documents that mention `person`, along with
    /// the person's resolved rollup id (`selectedPersonRollupId`) for rollup-scoped search.
    /// Resets to 0 / `nil` if `personMentionStore` is nil (e.g. during testing).
    public func loadPersonMentionCount(for person: PersonEntry) async {
        guard let store = personMentionStore else {
            selectedPersonMentionCount = 0
            selectedPersonRollupId = nil
            return
        }
        // Cross-corpus count via the person's rollup (resolved from this document's volume + ref).
        // The per-volume TEI `ref` collides across volumes, so an unscoped count would conflate
        // unrelated people; fall back to the correct same-volume count if the rollup isn't built yet.
        if let rollup = try? await store.rollupEntry(forVolumeId: entry.volumeId, ref: person.ref) {
            selectedPersonMentionCount = rollup.mentionCount
            selectedPersonRollupId = rollup.rollupId
        } else {
            selectedPersonMentionCount = (try? await store.documentCount(volumeId: entry.volumeId, ref: person.ref)) ?? 0
            selectedPersonRollupId = nil
        }
    }
}

// MARK: - Source Note Extraction

/// Searches `nodes` for a FRUS provenance note.
///
/// Delegates to `IndexingPipeline.extractSourceNote(from:)` — the canonical
/// implementation of the frus-sources locator chain (Source Explorer Phase 1) — so
/// the note displayed in the document Source sheet is byte-identical to the note the
/// indexing pipeline stores in `document_cache.source_note` and parses into
/// `document_sources`. See that method's documentation for the priority order and
/// the `[Source: …]` wrapper normalisation.
func extractSourceNote(from nodes: [FRUSASTNode]) -> String? {
    IndexingPipeline.extractSourceNote(from: nodes)
}

// MARK: - DocumentLoadError

public enum DocumentLoadError: LocalizedError {
    case documentNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .documentNotFound(let id):
            return "Document '\(id)' was not found in the volume."
        }
    }
}
