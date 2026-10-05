// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreSpotlight
import Foundation
import OSLog

// MARK: - IndexingPipeline + the app

/// The app's half of `IndexingPipeline`, which lives in FRUSCoreKit: what needs the app's bundle,
/// its settings, Spotlight or SwiftData.
///
/// - The initialiser every app call site uses, with the signature the pipeline had before it moved:
///   it passes the bundled resources, `UserDefaults` (`.standard` unless a test passes a suite) and
///   the Spotlight donor.
/// - ``IndexingResources/bundled``, the app's stores behind the kit's providers.
/// - Spotlight: the donated item's shape, its schema version and the rebuild.
/// - `updateSummary(_:)`, which takes the SwiftData summary.
///
/// Version history:
///   1.0 — Session 2026-10-04 (FRUSCoreKit, part 2): the Spotlight section, `updateSummary(_:)` and
///          the pipeline's old initialiser, moved out of `IndexingPipeline.swift` when it moved into
///          the kit; `IndexingResources.bundled` and `SpotlightDonor`, new with the kit's seams
extension IndexingPipeline {

    /// Creates a pipeline over the app's bundled resources, its settings and Spotlight.
    ///
    /// - Parameters:
    ///   - fts5Store: The shared FTS5 store. Must use the same `databaseURL`.
    ///   - databaseURL: Path to the shared SQLite database file.
    ///   - volumesDirectory: Directory containing downloaded volume XML files.
    ///   - stateTracker: Optional tracker for interrupted-indexing sentinel persistence.
    ///   - concurrencyLimit: Maximum simultaneous XML parsers. Default 4.
    ///   - defaults: Where the pipeline's stamps are kept. Default `.standard`.
    init(
        fts5Store: FTS5Store,
        databaseURL: URL,
        volumesDirectory: URL,
        stateTracker: IndexingStateTracker? = nil,
        concurrencyLimit: Int = 4,
        defaults: UserDefaults = .standard
    ) throws {
        try self.init(fts5Store: fts5Store, databaseURL: databaseURL, volumesDirectory: volumesDirectory,
                      resources: .bundled, stateTracker: stateTracker,
                      concurrencyLimit: concurrencyLimit, defaults: defaults, donor: SpotlightDonor())
    }

    /// Updates the summary text for a document that is already in the index.
    ///
    /// Writes `summary.responseText` to `document_cache`; the `user_content` FTS5
    /// sync trigger makes the new text immediately searchable.
    func updateSummary(_ summary: GeneratedSummary) async throws {
        try await updateSummaryText(
            volumeId: summary.volumeId,
            documentId: summary.documentId,
            responseText: summary.responseText
        )
    }

    // MARK: - Spotlight

    /// Builds a single `CSSearchableItem` from cached document fields, shared by
    /// `SpotlightDonor` and `rebuildSpotlightIndex()`. Internal so the test
    /// suite pins the donated shape against the real builder.
    ///
    /// ## `textContent` is the W-9 step 1 field
    /// `title` + `contentDescription` + `keywords` made documents findable by exact words.
    /// **`textContent` is the property Apple's on-device semantic search matches against**
    /// (`CSUserQuery` ranked results, and the system Spotlight UI) — the V-5 assessment
    /// measured that it was never set, which made the whole capability silently unavailable
    /// while every donation looked complete. The bound is **3,200 characters — the corpus's
    /// own chunk size** (`provenance.chunkChars`): the unit the semantic program already
    /// treats as one span of meaning, and a ceiling that keeps a full-corpus donation's text
    /// volume around a gigabyte rather than five.
    ///
    /// ## The title is the lists' title (#1372)
    /// It goes through `DocumentDisplayTitle`, so a Spotlight result names a document exactly as
    /// every in-app list does — in particular an editorial note whose printed head only says
    /// *Editorial Note* is *Editorial Note 2*, not one of 2,560 identical results.
    static func makeSearchableItem(
        volumeId: String, documentId: String, header: String, bodyText: String,
        documentNumber: String? = nil, isEditorialNote: Bool = false
    ) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = DocumentDisplayTitle.text(
            .init(header: header.isEmpty ? nil : header,
                  documentNumber: (documentNumber?.isEmpty == false) ? documentNumber : nil,
                  isEditorialNote: isEditorialNote),
            documentId: documentId)
        attrs.contentDescription = String(bodyText.prefix(300))
        attrs.keywords = [volumeId, documentId]
        attrs.textContent = String(bodyText.prefix(3_200))
        return CSSearchableItem(
            uniqueIdentifier: "\(volumeId)/\(documentId)",
            domainIdentifier: volumeId,
            attributeSet: attrs
        )
    }

    /// The donated item shape's version. Bump when `makeSearchableItem` changes what it
    /// donates; `rebuildSpotlightIndexIfNeeded` re-donates every already-indexed document
    /// once per bump, because Spotlight only learns a new field through re-submission.
    ///
    ///   1 — title / contentDescription / keywords (the original donation)
    ///   2 — + `textContent` (W-9 step 1)
    ///   3 — #1375 / #1372: re-donate after the index-v55 rebuild, whose titles lose the stray
    ///       markup-boundary spaces and whose editorial notes gain their heads. The v55 re-index
    ///       runs `indexAllVolumes()`, which never donates, so without this bump Spotlight would
    ///       keep "( Kennan )" and titles of the form "d245" until each volume was re-downloaded.
    ///       The title now also goes through `DocumentDisplayTitle`.
    ///   4 — #1421: re-donate after the index-v59 rebuild. `contentDescription` (the line under a
    ///       Spotlight result) and `textContent` are prefixes of `body_text`, which v59 re-joins as
    ///       printed; like v55's, the v59 re-index runs `indexAllVolumes()`, so without this bump
    ///       Spotlight would keep showing "Moscow , January 20, 1961 ." until each volume was
    ///       re-downloaded.
    static let currentSpotlightSchemaVersion = 4

    /// UserDefaults key holding the last donated schema version.
    static let spotlightSchemaVersionKey = "spotlightSchemaVersionApplied"

    /// Re-donates the Spotlight index once per `currentSpotlightSchemaVersion` bump — the
    /// `applyBrokenRefsIndexIfNeeded` idiom: gated, idempotent, cheap no-op when current.
    /// The stamp is written only after a successful rebuild, so a failed donation retries
    /// on the next launch rather than recording a coverage the index does not have.
    public func rebuildSpotlightIndexIfNeeded() async throws {
        let applied = UserDefaults.standard.integer(forKey: Self.spotlightSchemaVersionKey)
        guard applied != Self.currentSpotlightSchemaVersion else { return }
        try await rebuildSpotlightIndex()
        UserDefaults.standard.set(Self.currentSpotlightSchemaVersion,
                                  forKey: Self.spotlightSchemaVersionKey)
    }

    /// Rebuilds the on-device Spotlight index from `document_cache`, without
    /// re-parsing any volume XML (Session 154).
    ///
    /// Deletes every FRUS Explorer item from the system Spotlight index, then
    /// re-submits one `CSSearchableItem` per cached document using the header and
    /// body-text prefix already stored in `document_cache` — the same shape as
    /// `SpotlightDonor`, batched to avoid building one enormous array
    /// for a full-corpus rebuild. Use this to recover from a Spotlight index that
    /// has drifted from the on-disk search index without a full reindex.
    public func rebuildSpotlightIndex() async throws {
        try await CSSearchableIndex.default().deleteAllSearchableItems()

        // Each batch is read by `donatedDocuments(afterRowId:limit:)`, its statement fully
        // stepped and finalized before the Spotlight submission suspends: the actor is
        // reentrant, and an open statement held across an `await` could observe (or block)
        // another call mutating or rebuilding the database mid-iteration.
        var lastRowId: Int64 = 0
        var total = 0
        while true {
            let page = try donatedDocuments(afterRowId: lastRowId, limit: 500)
            lastRowId = page.lastRowId
            let batch = page.documents.map(Self.makeSearchableItem(for:))
            guard !batch.isEmpty else { break }
            try await CSSearchableIndex.default().indexSearchableItems(batch)
            total += batch.count
        }

        Self.spotlightLogger.info("rebuildSpotlightIndex: resubmitted \(total, privacy: .public) items")
    }

    /// The pipeline's log, for the Spotlight rebuild: the kit's own logger is private to it, so
    /// this one names the same subsystem and category.
    static let spotlightLogger = Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "IndexingPipeline")

    /// `makeSearchableItem` for a donated document.
    static func makeSearchableItem(for document: DonatedDocument) -> CSSearchableItem {
        makeSearchableItem(
            volumeId: document.volumeId, documentId: document.documentId,
            header: document.header, bodyText: document.bodyText,
            documentNumber: document.documentNumber, isEditorialNote: document.isEditorialNote
        )
    }
}

// MARK: - SpotlightDonor

/// Submits each indexed volume's documents to the default Spotlight index, and withdraws a removed
/// volume's. Errors are silently ignored — Spotlight is best-effort.
///
/// Version history:
///   1.0 — Session 2026-10-04 (FRUSCoreKit, part 2): `IndexingPipeline.submitSpotlightItems(for:)`
///          and `removeVolume`'s Spotlight delete, as the pipeline's donor
struct SpotlightDonor: IndexedDocumentDonor {

    /// Submits CSSearchableItem records for all of a volume's documents.
    func donate(volumeId: String, documents: [DonatedDocument]) {
        let items = documents.map(IndexingPipeline.makeSearchableItem(for:))
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    /// Deletes every item donated for the volume.
    func withdraw(volumeId: String) async {
        try? await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [volumeId])
    }
}

// MARK: - IndexingResources + the app's bundle

extension IndexingResources {

    /// The app's bundled data files, through the stores that already hold them, so each decode keeps
    /// its first-use timing and the app holds one copy (#736).
    static let bundled = IndexingResources(
        personAuthority: { PersonAuthorityIndexStore.shared },
        documentSubjects: { DocumentSubjectStore.shared },
        decimalClassLabels: { DecimalClassLabelStore.shared },
        brokenRefs: { BrokenRefsIndexStore.shared },
        collectionAliasFallback: { parsed, raw in
            CollectionAuthorityStore.shared?.record(forParsed: parsed, note: raw)
                .map(IndexingPipeline.CollectionAliasFallback.init(record:))
        })
}

// MARK: - UserDefaults + IndexingStampStore

/// `UserDefaults` already has every method the stamp store asks for, under the same names.
extension UserDefaults: IndexingStampStore {}
