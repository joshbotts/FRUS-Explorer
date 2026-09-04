// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionGeneratedBlockType

/// The vocabulary of generated apparatus blocks (Authoring Phase 6, decision A11):
/// placeable `CollectionEntryKind.generated` entries whose content is computed from the
/// collection's resolved document set at resolve time — never authored, never stored.
///
/// The raw value is the persisted `CollectionEntry.generatedBlockType` string AND the
/// `.fruscollection` `generatedBlockType` key, so it must never be renamed. An unknown
/// raw value (written by a newer app version, via CloudKit sync or a shared file) reads
/// as `nil` here; the entry stays inert (see `CollectionEntry.generatedBlockType`) and
/// the resolver skips it — degraded, never corrupted.
///
/// Version history:
///   1.0 — Authoring Phase 6 (core): the five block types, display metadata, and the
///          default-position hint driving the Apparatus menu's live insertion point
enum CollectionGeneratedBlockType: String, CaseIterable, Identifiable, Sendable {
    /// Deduplicated, sorted citations of every document in the collection.
    case bibliography
    /// The collection's documents in date order (the `document_dates` data).
    case chronology
    /// The archival collections the documents draw on, with NARA links where resolved.
    case archivalSources
    /// Persons mentioned across the collection's documents, rolled up by identity.
    case personsIndex
    /// The researcher's tags mapped to the documents that carry them.
    case thematicIndex

    var id: String { rawValue }

    /// Where the Apparatus menu inserts a new block by default. The entry remains fully
    /// movable afterwards — this is an insertion hint, not a constraint.
    enum DefaultPosition: Sendable {
        /// Inserted before the first entry (e.g. a chronology that opens the reader).
        case frontMatter
        /// Appended after the last entry (classic back-matter apparatus).
        case backMatter
    }

    /// The localized block title — used by the editors' rows and menus AND as the
    /// resolved block's rendered section title, so the artifact and the editor agree.
    var displayName: String {
        switch self {
        case .bibliography:
            return String(localized: "collection.generated.bibliography",
                          defaultValue: "Bibliography")
        case .chronology:
            return String(localized: "collection.generated.chronology",
                          defaultValue: "Chronology")
        case .archivalSources:
            return String(localized: "collection.generated.archivalSources",
                          defaultValue: "Sources & Archives")
        case .personsIndex:
            return String(localized: "collection.generated.personsIndex",
                          defaultValue: "Persons Index")
        case .thematicIndex:
            return String(localized: "collection.generated.thematicIndex",
                          defaultValue: "Thematic Index")
        }
    }

    /// SF Symbol for the editors' rows and the Apparatus menu.
    var systemImage: String {
        switch self {
        case .bibliography:    return "books.vertical"
        case .chronology:      return "calendar"
        case .archivalSources: return "archivebox"
        case .personsIndex:    return "person.2"
        case .thematicIndex:   return "tag"
        }
    }

    /// The default insertion position: a chronology reads naturally as front matter;
    /// every other apparatus block is classic back matter.
    var defaultPosition: DefaultPosition {
        switch self {
        case .chronology: return .frontMatter
        case .bibliography, .archivalSources, .personsIndex, .thematicIndex:
            return .backMatter
        }
    }
}

// MARK: - CollectionGeneratedBlockDataSource

/// Everything the real block resolvers read, injected by `CollectionContentResolver`
/// (the production implementation is its `LiveGeneratedBlockDataSource`, wired to the
/// FTS5 index, the person rollup, the bundled NARA resolution index, and SwiftData).
/// Tests supply a fixture implementation, so per-block resolution logic stays hermetic —
/// no SQLite, no SwiftData, no bundle resources.
///
/// All methods are **read-only** by contract: a data source must never download volumes,
/// never generate content, and answer identically for `.preview` and `.export` resolves.
///
/// Version history:
///   1.0 — Authoring Phase 6 (blocks): initial implementation
@MainActor
protocol CollectionGeneratedBlockDataSource {

    /// The history.state.gov-style citation for one document — the same manifest +
    /// formatter path document items use (header-independent: the formatter reads only
    /// volume metadata and the document number, so no volume XML is ever needed).
    /// Falls back to `"volumeId/documentId"` for unknown volumes.
    func citation(volumeId: String, documentId: String) -> String

    /// Structured date metadata (`document_dates`) keyed by `"volumeId/documentId"`.
    /// Documents with no indexed date are simply absent from the result.
    func dateMetadata(
        for documents: [(volumeId: String, documentId: String)]
    ) async -> [String: DocumentDateMetadata]

    /// The parsed per-document source-note rows (`document_sources`) for the given
    /// documents. Documents whose source note was never indexed are absent.
    func documentSources(
        for documents: [(volumeId: String, documentId: String)]
    ) async -> [CollectionGeneratedBlocks.SourceRecord]

    /// The bundled NARA Catalog resolution for an archival collection
    /// (`VolumeSourcesIndexStore` — lot file first, else record group), or `nil`.
    func archivalResolution(recordGroup: String?, lotFile: String?)
        -> CollectionGeneratedBlocks.ArchivalLink?

    /// Person mentions in the given documents, resolved through the materialised
    /// People-browser rollup (`person_rollup` — one element per identity × mentioning
    /// document). Empty when the rollup hasn't been built, matching the People browser.
    func personMentions(
        for documents: [(volumeId: String, documentId: String)]
    ) async -> [CollectionGeneratedBlocks.PersonMention]

    /// Every user tag with the documents it reaches — the Phase 3 union of
    /// `ResearchNote.userTagIds` and `DocumentTagAssignment`
    /// (`CollectionDocumentDiscovery.tagDocumentRefs`). The thematic block intersects
    /// each tag's reach with the collection membership itself.
    func tagRecords() async -> [CollectionGeneratedBlocks.TagRecord]
}

// MARK: - CollectionGeneratedBlocks

/// The block-resolution seam (Authoring Phase 6): turns a generated entry's block type
/// plus the collection's resolved document membership into the pre-resolved
/// `CollectionGeneratedBlock` payload exporters render. Called only by
/// `CollectionContentResolver` — the single resolve pipeline — so `.preview` and
/// `.export` produce identical blocks by construction (block resolution is read-only:
/// it never downloads volumes and never generates content).
///
/// ## Per-block data paths (all read-only, all already-indexed data)
/// - **Bibliography** — the same citation path document items use, deduplicated by
///   `(volumeId, documentId)` and sorted by volume then document number (series order —
///   FRUS citations have no author-first form, so alphabetical-by-author doesn't apply).
/// - **Chronology** — `document_dates` metadata, formatted at its true precision
///   (year/month/day); date order, membership order breaking ties; undated documents in
///   a trailing "Undated" group.
/// - **Sources & Archives** — `document_sources` structured rows grouped by archival
///   collection, enriched with the bundled NARA Catalog resolutions (lot file first,
///   else record group); referencing documents listed beneath at indent 1.
/// - **Persons Index** — `person_mentions` joined through the materialised People-browser
///   rollup (`person_rollup`); clustering is NEVER reimplemented here. Threshold: a
///   person appears when mentioned in ≥ 2 of the collection's documents if the
///   collection has ≥ 4 documents, else ≥ 1 (no knob — small collections list everyone,
///   larger ones filter walk-on mentions).
/// - **Thematic Index** — user tags via the Phase 3 union (notes + direct assignments),
///   intersected with the membership; tags reaching no collection document are skipped.
///
/// Rows are **never serialized** (not into `.fruscollection` files, not into SwiftData):
/// only the block TYPE persists, and every device re-resolves rows against its own data.
/// Every block that resolves to nothing renders one localized "nothing to list" row —
/// never an empty section.
///
/// Version history:
///   1.0 — Authoring Phase 6 (core): the seam + placeholder resolution for all types
///   1.1 — Authoring Phase 6 (blocks): the five real resolvers behind the injected
///          `CollectionGeneratedBlockDataSource`; placeholders removed
///   1.2 — Authoring Phase 6 review fixes: persons-index ordering made deterministic
///          across launches (identity key breaks canonical-name ties — Dictionary
///          iteration order is seeded per launch and `sorted(by:)` is not stable)
enum CollectionGeneratedBlocks {

    /// Resolves one generated block from the collection's resolved document membership.
    ///
    /// - Parameters:
    ///   - type: The block type to resolve.
    ///   - documents: The collection's resolved document membership — `(volumeId,
    ///     documentId)` in collection order, deduplicated (the same universe the A10
    ///     related-documents line uses; for smart collections it is the resolved search
    ///     result set, so blocks work there identically).
    ///   - dataSource: The read-only data seam (see
    ///     `CollectionGeneratedBlockDataSource`).
    /// - Returns: The pre-resolved block payload; never empty — a block with nothing to
    ///   list carries one localized explanatory row.
    @MainActor
    static func resolve(
        type: CollectionGeneratedBlockType,
        documents: [(volumeId: String, documentId: String)],
        dataSource: some CollectionGeneratedBlockDataSource
    ) async -> CollectionGeneratedBlock {
        let rows: [CollectionGeneratedRow]
        switch type {
        case .bibliography:
            rows = bibliographyRows(documents: documents, dataSource: dataSource)
        case .chronology:
            rows = await chronologyRows(documents: documents, dataSource: dataSource)
        case .archivalSources:
            rows = await archivalSourceRows(documents: documents, dataSource: dataSource)
        case .personsIndex:
            rows = await personsIndexRows(documents: documents, dataSource: dataSource)
        case .thematicIndex:
            rows = await thematicIndexRows(documents: documents, dataSource: dataSource)
        }
        return CollectionGeneratedBlock(
            type: type,
            title: type.displayName,
            rows: rows.isEmpty ? [CollectionGeneratedRow(text: emptyRowText)] : rows)
    }

    /// The "nothing to list" row every block falls back to — a block never renders as
    /// a bare title over an empty list.
    static var emptyRowText: String {
        String(localized: "collection.generated.emptyRow",
               defaultValue: "Nothing to list — this collection’s documents provided no entries for this block.")
    }

    // MARK: - Data records

    /// One parsed `document_sources` row: the structured archival-provenance fields the
    /// indexer extracted from a document's source note, plus the raw note text as the
    /// grouping fallback when nothing structured was recognized.
    struct SourceRecord: Sendable {
        /// The document's volume.
        let volumeId: String
        /// The document's id within the volume.
        let documentId: String
        /// The holding repository (e.g. "National Archives"), when parsed.
        let repository: String?
        /// The NARA record-group number (e.g. `"59"`), when parsed.
        let recordGroup: String?
        /// The lot-file citation (e.g. `"64 D 199"`), when parsed.
        let lotFile: String?
        /// The series/collection name, when parsed.
        let seriesName: String?
        /// The raw source-note text (grouping fallback for unrecognized citations).
        let rawText: String
        /// The parser's classification of the citation form — see
        /// `DocumentArchivalSource.citationEra`. Carried so the trip packet can reach
        /// `SourceProvenanceCategory` without a second classifier (#830 T-2).
        let citationEra: String?

        /// Creates a source record.
        init(volumeId: String, documentId: String, repository: String?,
             recordGroup: String?, lotFile: String?, seriesName: String?, rawText: String,
             citationEra: String? = nil) {
            self.volumeId = volumeId
            self.documentId = documentId
            self.repository = repository
            self.recordGroup = recordGroup
            self.lotFile = lotFile
            self.seriesName = seriesName
            self.rawText = rawText
            self.citationEra = citationEra
        }
    }

    /// A resolved NARA Catalog link for an archival collection: the authority title and
    /// the `catalog.archives.gov` URL string (rows carry URL strings, not `URL`).
    struct ArchivalLink: Sendable {
        /// The catalog record's authority title.
        let title: String
        /// The canonical catalog URL string.
        let urlString: String

        /// Creates an archival link.
        init(title: String, urlString: String) {
            self.title = title
            self.urlString = urlString
        }
    }

    /// One person identity × mentioning document pair from the People-browser rollup.
    struct PersonMention: Sendable {
        /// Stable identity key (the rollup id, stringified) — mentions with the same
        /// key are the same person.
        let identityKey: String
        /// The rollup's canonical display name.
        let name: String
        /// The rollup's description (front-matter role text), when available.
        let description: String?
        /// The rollup's role classification, when available.
        let role: String?
        /// The mentioning document's volume.
        let volumeId: String
        /// The mentioning document's id.
        let documentId: String

        /// Creates a person-mention record.
        init(identityKey: String, name: String, description: String?, role: String?,
             volumeId: String, documentId: String) {
            self.identityKey = identityKey
            self.name = name
            self.description = description
            self.role = role
            self.volumeId = volumeId
            self.documentId = documentId
        }
    }

    /// One user tag with every document it reaches (union of note tags and direct
    /// assignments), before intersection with the collection membership.
    struct TagRecord: Sendable {
        /// The tag's display name.
        let name: String
        /// The documents the tag reaches, deduplicated.
        let documents: [(volumeId: String, documentId: String)]

        /// Creates a tag record.
        init(name: String, documents: [(volumeId: String, documentId: String)]) {
            self.name = name
            self.documents = documents
        }
    }

    // MARK: - Bibliography

    /// Bibliography rows: one full citation per distinct document, sorted by volume id
    /// then document number — series order, the order a reader consults FRUS. (FRUS
    /// document citations have no author-first form, so the classic alphabetical-by-
    /// author bibliography ordering does not apply; volume + document order is the
    /// scholarly-sensible equivalent and is stable across devices.)
    @MainActor
    private static func bibliographyRows(
        documents: [(volumeId: String, documentId: String)],
        dataSource: some CollectionGeneratedBlockDataSource
    ) -> [CollectionGeneratedRow] {
        // Defensive dedupe (membership arrives deduplicated, but the block's contract
        // is "each document cited once" regardless of caller).
        var seen = Set<String>()
        let distinct = documents.filter { seen.insert(documentKey($0)).inserted }
        let sorted = distinct.sorted { a, b in
            if a.volumeId != b.volumeId {
                return a.volumeId.localizedStandardCompare(b.volumeId) == .orderedAscending
            }
            switch (documentNumber(a.documentId), documentNumber(b.documentId)) {
            case (let x?, let y?): return x < y
            case (_?, nil):        return true
            case (nil, _?):        return false
            case (nil, nil):
                return a.documentId.localizedStandardCompare(b.documentId) == .orderedAscending
            }
        }
        return sorted.map {
            CollectionGeneratedRow(text: dataSource.citation(volumeId: $0.volumeId,
                                                             documentId: $0.documentId))
        }
    }

    // MARK: - Chronology

    /// Chronology rows: dated documents ascending by `date_iso` (membership order
    /// breaking ties), each as a precision-honest date + the document's citation;
    /// undated documents follow in a trailing "Undated" group (a heading row with the
    /// documents indented beneath it).
    @MainActor
    private static func chronologyRows(
        documents: [(volumeId: String, documentId: String)],
        dataSource: some CollectionGeneratedBlockDataSource
    ) async -> [CollectionGeneratedRow] {
        let metadata = await dataSource.dateMetadata(for: documents)

        var dated: [(index: Int, doc: (volumeId: String, documentId: String),
                     meta: DocumentDateMetadata)] = []
        var undated: [(volumeId: String, documentId: String)] = []
        for (i, doc) in documents.enumerated() {
            if let meta = metadata[documentKey(doc)] {
                dated.append((i, doc, meta))
            } else {
                undated.append(doc)
            }
        }
        // ISO `yyyy-MM-dd` strings sort correctly as strings; membership order breaks ties.
        dated.sort {
            ($0.meta.dateISO, $0.index) < ($1.meta.dateISO, $1.index)
        }

        var rows: [CollectionGeneratedRow] = dated.map { item in
            CollectionGeneratedRow(
                text: dateLabel(for: item.meta),
                secondaryText: dataSource.citation(volumeId: item.doc.volumeId,
                                                   documentId: item.doc.documentId))
        }
        if !undated.isEmpty {
            rows.append(CollectionGeneratedRow(
                text: String(localized: "collection.generated.chronology.undated",
                             defaultValue: "Undated")))
            rows.append(contentsOf: undated.map {
                CollectionGeneratedRow(text: dataSource.citation(volumeId: $0.volumeId,
                                                                 documentId: $0.documentId),
                                       indentLevel: 1)
            })
        }
        return rows
    }

    /// Formats a date at its true stored precision — "1969", "February 1969", or the
    /// long day form — honest to the source TEI rather than the padded ISO value.
    /// A range (`dateISOMax` differing from `dateISO`) renders as "start – end".
    private static func dateLabel(for meta: DocumentDateMetadata) -> String {
        let start = dateLabel(iso: meta.dateISO, precision: meta.precision)
        if let maxISO = meta.dateISOMax, maxISO != meta.dateISO {
            return "\(start) – \(dateLabel(iso: maxISO, precision: meta.precision))"
        }
        return start
    }

    /// Formats one padded ISO date string (`yyyy-MM-dd`) at the given precision.
    /// `nil` precision (legacy rows) formats at day granularity, matching the stored
    /// normalized value. Falls back to the raw string when it cannot be parsed.
    private static func dateLabel(iso: String, precision: DatePrecision?) -> String {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard let year = parts.first else { return iso }
        var comps = DateComponents()
        comps.year = year
        comps.month = parts.count > 1 ? parts[1] : 1
        comps.day = parts.count > 2 ? parts[2] : 1
        guard let date = Calendar(identifier: .gregorian).date(from: comps) else { return iso }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        switch precision ?? .day {
        case .year:  formatter.dateFormat = "yyyy"
        case .month: formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        case .day:   formatter.dateStyle = .long
        }
        return formatter.string(from: date)
    }

    // MARK: - Sources & Archives

    /// Sources & Archives rows: the documents' `document_sources` rows grouped by
    /// archival collection — key `(repository, recordGroup, lotFile, seriesName)`, with
    /// the raw note text as the grouping fallback when nothing structured was parsed —
    /// sorted by label. Each group row carries the bundled NARA Catalog resolution
    /// (authority title + catalog link) when one exists; the referencing documents
    /// follow at indent 1, in collection order.
    @MainActor
    private static func archivalSourceRows(
        documents: [(volumeId: String, documentId: String)],
        dataSource: some CollectionGeneratedBlockDataSource
    ) async -> [CollectionGeneratedRow] {
        let records = await dataSource.documentSources(for: documents)
        guard !records.isEmpty else { return [] }
        let recordsByKey = Dictionary(records.map { (documentKey(($0.volumeId, $0.documentId)), $0) },
                                      uniquingKeysWith: { first, _ in first })

        // Group in membership order so document lists come out in collection order.
        var groups: [String: SourceGroup] = [:]
        var order: [String] = []
        for doc in documents {
            guard let record = recordsByKey[documentKey(doc)] else { continue }
            let key = groupKey(for: record)
            if groups[key] == nil {
                groups[key] = SourceGroup(record: record)
                order.append(key)
            }
            groups[key]?.docs.append(doc)
        }

        let multiVolume = spansMultipleVolumes(documents)
        let sortedGroups = order
            .compactMap { groups[$0] }
            .sorted { label(for: $0.record).localizedStandardCompare(label(for: $1.record))
                == .orderedAscending }

        var rows: [CollectionGeneratedRow] = []
        for group in sortedGroups {
            let link = dataSource.archivalResolution(recordGroup: group.record.recordGroup,
                                                     lotFile: group.record.lotFile)
            rows.append(CollectionGeneratedRow(
                text: label(for: group.record),
                secondaryText: link?.title,
                url: link?.urlString))
            rows.append(contentsOf: group.docs.map {
                CollectionGeneratedRow(text: referenceRowText($0, multiVolume: multiVolume),
                                       indentLevel: 1)
            })
        }
        return rows
    }

    /// The display label, shared with the trip packet (#830 T-2) so a packet target reads
    /// like a Sources-block group. The grouping KEY is no longer shared: Archive Visits
    /// Phase 1 moved the packet to form-aware unit-grain keys (`TripPacketBuilder.targetKey`),
    /// because this block's key rides the per-document file identifier for central files —
    /// document grain, which is right for a per-volume outline and wrong for a research target.
    static func tripPacketLabel(for record: SourceRecord) -> String { label(for: record) }

    private static func groupKey(for record: SourceRecord) -> String {
        let structured = [record.repository, record.recordGroup,
                          record.lotFile, record.seriesName]
        if structured.contains(where: { !($0 ?? "").isEmpty }) {
            return "s|" + structured.map { $0 ?? "" }.joined(separator: "|")
        }
        return "r|" + record.rawText
    }

    /// The display label for an archival collection group: series name, lot file,
    /// record group, and repository in that order (most to least specific), joined with
    /// commas. Falls back to the truncated raw note text when nothing was parsed.
    private static func label(for record: SourceRecord) -> String {
        var parts: [String] = []
        if let series = record.seriesName, !series.isEmpty { parts.append(series) }
        if let lot = record.lotFile, !lot.isEmpty {
            parts.append(String(localized: "collection.generated.sources.lot",
                                defaultValue: "Lot \(lot)"))
        }
        // `document_sources.record_group` stores TWO forms, and the difference is provenance,
        // not meaning: where a citation names its record group the parser captures a bare
        // "59"; where it names none (a decimal file number does not) the parser infers one and
        // writes the literal "RG-59". Interpolating the latter after "RG " printed
        // "…, RG RG-59, Department of State". Source Explorer hit this exact bug and patched it
        // (`SourceExplorerView.swift:466`); this surface never got the fix, and 93% of the
        // corpus's export groups carry the prefixed form.
        if let rg = CollectionKeying.bareRG(record.recordGroup), !rg.isEmpty {
            parts.append(String(localized: "collection.generated.sources.recordGroup",
                                defaultValue: "RG \(rg)"))
        }
        if let repo = record.repository, !repo.isEmpty { parts.append(repo) }
        if parts.isEmpty {
            let trimmed = record.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count > 140 ? String(trimmed.prefix(140)) + "…" : trimmed
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Persons Index

    /// Persons Index rows: rollup identities mentioned in the collection's documents,
    /// alphabetical by canonical name (identity key breaks ties, so equal-named
    /// identities keep a stable order across launches). **Threshold heuristic (no knob):** with ≥ 4
    /// documents in the collection a person must be mentioned in ≥ 2 of them (filters
    /// walk-on mentions); smaller collections list every mentioned person (≥ 1) — a
    /// 2-document collection would otherwise produce a near-empty index. Each row is the
    /// name plus description/role and a "Documents N, M, …" reference list (document
    /// numbers, falling back to ids; volume-qualified when the collection spans volumes).
    @MainActor
    private static func personsIndexRows(
        documents: [(volumeId: String, documentId: String)],
        dataSource: some CollectionGeneratedBlockDataSource
    ) async -> [CollectionGeneratedRow] {
        let mentions = await dataSource.personMentions(for: documents)
        guard !mentions.isEmpty else { return [] }

        var identities: [String: PersonIdentity] = [:]
        for mention in mentions {
            var identity = identities[mention.identityKey]
                ?? PersonIdentity(name: mention.name, description: mention.description,
                                  role: mention.role)
            identity.documentKeys.insert(documentKey((mention.volumeId, mention.documentId)))
            identities[mention.identityKey] = identity
        }

        // Threshold: ≥ 2 mentioning documents when the collection has ≥ 4 documents,
        // else ≥ 1. Documented heuristic — deliberately not user-configurable.
        let threshold = documents.count >= 4 ? 2 : 1
        let multiVolume = spansMultipleVolumes(documents)

        return identities
            .filter { $0.value.documentKeys.count >= threshold }
            // Deterministic order across launches: name first, identity key breaking
            // ties — Dictionary iteration order is per-launch-seeded and `sorted(by:)`
            // is not stable, so equal-named identities would otherwise swap between
            // runs (same collection, differently ordered exports).
            .sorted { a, b in
                let nameOrder = a.value.name.localizedStandardCompare(b.value.name)
                if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
                return a.key < b.key
            }
            .map(\.value)
            .map { identity in
                // Reference list in collection order (the reader's order).
                let refs = documents
                    .filter { identity.documentKeys.contains(documentKey($0)) }
                    .map { referenceToken($0, multiVolume: multiVolume) }
                let refList = refs.count == 1
                    ? String(localized: "collection.generated.persons.document",
                             defaultValue: "Document \(refs[0])")
                    : String(localized: "collection.generated.persons.documents",
                             defaultValue: "Documents \(refs.joined(separator: ", "))")
                let detail = identity.description ?? identity.role
                let secondary = [detail, refList].compactMap { $0 }.joined(separator: " — ")
                return CollectionGeneratedRow(text: identity.name, secondaryText: secondary)
            }
    }

    // MARK: - Thematic Index

    /// Thematic Index rows: the user's tags that reach at least one collection document
    /// (via research notes or direct assignments — the Phase 3 union), alphabetical by
    /// tag name; each tag's collection documents follow at indent 1, in collection
    /// order. Tags reaching no collection document are skipped entirely.
    @MainActor
    private static func thematicIndexRows(
        documents: [(volumeId: String, documentId: String)],
        dataSource: some CollectionGeneratedBlockDataSource
    ) async -> [CollectionGeneratedRow] {
        let tags = await dataSource.tagRecords()
        guard !tags.isEmpty else { return [] }
        let multiVolume = spansMultipleVolumes(documents)

        var rows: [CollectionGeneratedRow] = []
        for tag in tags.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            let reach = Set(tag.documents.map(documentKey))
            let members = documents.filter { reach.contains(documentKey($0)) }
            guard !members.isEmpty else { continue }
            rows.append(CollectionGeneratedRow(text: tag.name))
            rows.append(contentsOf: members.map {
                CollectionGeneratedRow(text: referenceRowText($0, multiVolume: multiVolume),
                                       indentLevel: 1)
            })
        }
        return rows
    }

    // MARK: - Shared helpers

    /// Accumulator for one archival-collection group: the representative source record
    /// plus the referencing documents in membership order.
    private struct SourceGroup {
        /// The representative parsed source row (labels + resolution keys).
        let record: SourceRecord
        /// The referencing documents, in collection order.
        var docs: [(volumeId: String, documentId: String)] = []
    }

    /// Accumulator for one person identity while grouping rollup mentions.
    private struct PersonIdentity {
        /// The rollup's canonical display name.
        let name: String
        /// The rollup's description, when available.
        let description: String?
        /// The rollup's role classification, when available.
        let role: String?
        /// The distinct mentioning-document keys.
        var documentKeys: Set<String> = []
    }

    /// The canonical `"volumeId/documentId"` key.
    private static func documentKey(_ doc: (volumeId: String, documentId: String)) -> String {
        "\(doc.volumeId)/\(doc.documentId)"
    }

    /// The numeric document number parsed from a `"d<n>"` id, or `nil`.
    private static func documentNumber(_ documentId: String) -> Int? {
        documentId.hasPrefix("d") ? Int(documentId.dropFirst()) : nil
    }

    /// Whether the membership spans more than one volume — when it does, document
    /// references are volume-qualified, since bare document numbers would be ambiguous.
    private static func spansMultipleVolumes(
        _ documents: [(volumeId: String, documentId: String)]
    ) -> Bool {
        Set(documents.map(\.volumeId)).count > 1
    }

    /// A short reference token for inline lists: the document number (else the raw id),
    /// volume-qualified when the collection spans volumes (e.g. `"12 (frus1969-76v01)"`).
    private static func referenceToken(
        _ doc: (volumeId: String, documentId: String), multiVolume: Bool
    ) -> String {
        let base = documentNumber(doc.documentId).map(String.init) ?? doc.documentId
        return multiVolume ? "\(base) (\(doc.volumeId))" : base
    }

    /// A short reference row for indent-1 document lists (sources & thematic blocks):
    /// "Document 12", volume-qualified when the collection spans volumes.
    private static func referenceRowText(
        _ doc: (volumeId: String, documentId: String), multiVolume: Bool
    ) -> String {
        String(localized: "collection.generated.documentRef",
               defaultValue: "Document \(referenceToken(doc, multiVolume: multiVolume))")
    }
}
