// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - GeneratedSummary

/// An AI-generated summary of a FRUS document.
///
/// Summaries are produced by `SummarizationProvider` implementations (Session 19).
/// They are attached to a specific document and prompt, and tagged with the project
/// active at generation time. Users can promote summaries to `ResearchNote` draft
/// content by adding the summary's `id` to `ResearchNote.selectedSummaryIds`.
///
/// ## Chunking
/// Long documents that exceed the AI model's context window are summarized in chunks.
/// `wasChunked` records whether chunking was applied; this is surfaced to the user
/// in the Document view so they understand the summary covers all sections.
///
/// ## Format
/// `responseFormat` records whether the summary is free-form prose (`.general`) or
/// a structured JSON object (`.structured`). The Document view renders structured
/// summaries as a labeled field list.
///
/// ## Sendability
/// Marked `@unchecked Sendable` so `SummarizationService.summarize()` can return
/// the persisted model across the actor boundary to callers. Instances are only ever
/// mutated through the `ModelContext` that owns them, which enforces its own thread safety.
///
/// Version history:
///   1.0 — Session 04: initial implementation
///   1.1 — Session 32: `@unchecked Sendable` documented as planned; conformance was
///          mistakenly omitted from source
///   1.2 — Session 128: `@unchecked Sendable` conformance added (fixes Swift 6 strict-
///          concurrency errors in `SummarizationServiceTests`)
///   1.3 — Session 130: investigated "redundant conformance" warning. Root cause: the
///          `@Model` macro in iOS/macOS 26 unconditionally synthesizes a plain `Sendable`
///          conformance in its macro expansion, which conflicts with our explicit
///          `@unchecked Sendable`. The explicit declaration cannot be removed: without it
///          `SummarizationServiceTests` fails because the macro's plain `Sendable`
///          uses strict checking that rejects the actor-boundary crossing in
///          `SummarizationService.summarize()`. This is a deficiency in the `@Model`
///          macro — it should not synthesize `Sendable` when the type already declares
///          it. The warning is located in the generated macro expansion file, not in
///          this source, and is harmless. Track for removal when Apple fixes the macro.
///   1.4 — R-5 P3b-1: `newestNonDraftPerDocument` / `draftOnlyDocuments` — statics only; no stored
///          property, no CloudKit change
///   1.5 — R-5 P3b-2: `sourceContentHash` — the revision hash of the text a summary describes.
///          A NEW mirrored field: it boards the ninth Production promotion.
@Model final class GeneratedSummary: @unchecked Sendable {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Document Reference

    var documentId: String = "" {
        didSet { lastModified = .now }
    }

    var volumeId: String = "" {
        didSet { lastModified = .now }
    }

    // MARK: - Content

    /// The `SummarizationPrompt.id` that produced this summary.
    var promptId: UUID = UUID() {
        didSet { lastModified = .now }
    }

    /// The raw text returned by the AI model. For `.structured` format this is
    /// a JSON string conforming to the prompt's `StructuredSummarySchema`.
    var responseText: String = "" {
        didSet { lastModified = .now }
    }

    /// Controls how `responseText` should be interpreted and rendered.
    ///
    /// Stored as a Codable type; SwiftData serializes it for CloudKit sync.
    var responseFormat: ResponseFormat = ResponseFormat.general {
        didSet { lastModified = .now }
    }

    /// `true` if the document was too long for a single model call and was
    /// split into sections, summarized individually, then merged.
    var wasChunked: Bool = false {
        didSet { lastModified = .now }
    }

    /// Who authored this summary's text — the on-device AI (default), the AI then edited by the
    /// user, or the user from scratch (Composer redesign, editable headnotes). The export
    /// attribution reads this so a user-written or -edited headnote is never mislabeled
    /// "AI-generated".
    ///
    /// **Optional on purpose.** SwiftData does not backfill a stored default onto rows persisted
    /// before this field was added (including CloudKit-synced records), so the column reads back
    /// NULL for them. A *non-optional* enum property force-casts that NULL and traps at the getter
    /// (`Could not cast value of type 'Swift.Optional<Any>' to 'SummaryAuthorship'`). Declaring it
    /// optional lets a legacy NULL surface as `nil`; every read site coerces `nil` to `.aiGenerated`,
    /// so legacy summaries are attributed exactly as before while new rows still default to
    /// `.aiGenerated`. (Primitive fields like `isHeadnoteDraft` don't need this — SwiftData coerces a
    /// NULL primitive to its zero value. A non-optional *custom* type added to an already-persisted
    /// model traps the same way whether it is an enum or a `Codable` value, so any such field added
    /// later should be optional. Fields present since the model's first commit — e.g. `responseFormat`
    /// — have no legacy NULL rows and are safe as-is.)
    var authorship: SummaryAuthorship? = SummaryAuthorship.aiGenerated {
        didSet { lastModified = .now }
    }

    /// `true` for a summary that exists solely as a collection entry's editable headnote draft
    /// (Composer redesign). Such summaries are excluded from the document's summary carousel and
    /// the headnote-source picker, so editing a headnote never pollutes the document's summaries.
    /// `false` for every ordinary summary. Defaults to `false`, so existing summaries are unaffected.
    var isHeadnoteDraft: Bool = false {
        didSet { lastModified = .now }
    }

    // MARK: - Provenance of the text summarised (R-5 P3b-2)

    /// The `document_revisions.content_hash` of the text this summary describes, read at
    /// generation, or `nil` when the document was not indexed then — and on every summary made
    /// before this field existed.
    ///
    /// It is the revision row's own hash, never a hash of the text handed to the summariser:
    /// three different recipes feed that text (the document view's `\n\n` join, the background
    /// runner's, the export's space-joined `body_text`) and `contentHash` hashes the stored
    /// columns instead, so no text hash could ever compare equal.
    ///
    /// **No `didSet`, unlike every neighbouring property.** Those observers never fire on a
    /// `@Model` stored property, and nothing should ever rewrite this value: a summary describes
    /// the text it was made from, permanently.
    ///
    /// **One known imprecision, on the bulk path only, and a reader of this field must allow for
    /// it.** `SummarizationService.summarize` reads the hash as each document begins. A bulk run
    /// materialises every document's text up front and then summarises for hours, so if a volume
    /// is updated mid-run, a later job in that volume is summarised from the text captured before
    /// the update while the hash recorded is the one after it — the summary would read as
    /// describing the current text when it describes the earlier one. Closing this means carrying
    /// the hash beside the text through `BackgroundSummarizationService`'s job list, which needs a
    /// pipeline reference that service does not have; it is an obligation of the phase that first
    /// READS this field (design §8.2, P3b-5), not of the phase that writes it.
    var sourceContentHash: String? = nil

    // MARK: - Project Context

    /// The project active at generation time. `nil` if generated in global context.
    var projectId: UUID? {
        didSet { lastModified = .now }
    }

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var lastModified: Date?

    // MARK: - Initializer

    init(
        documentId: String,
        volumeId: String,
        promptId: UUID,
        responseText: String,
        responseFormat: ResponseFormat = .general,
        wasChunked: Bool = false,
        projectId: UUID? = nil,
        authorship: SummaryAuthorship = .aiGenerated,
        isHeadnoteDraft: Bool = false,
        sourceContentHash: String? = nil
    ) {
        self.id = UUID()
        self.documentId = documentId
        self.volumeId = volumeId
        self.promptId = promptId
        self.responseText = responseText
        self.responseFormat = responseFormat
        self.wasChunked = wasChunked
        self.projectId = projectId
        self.authorship = authorship
        self.isHeadnoteDraft = isHeadnoteDraft
        self.sourceContentHash = sourceContentHash
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] GeneratedSummary created: \(id) for \(volumeId)/\(documentId)")
        #endif
    }
}

// MARK: - SummaryAuthorship

/// The provenance of a `GeneratedSummary`'s text (Composer redesign). Lets exports attribute a
/// user-written or -edited headnote honestly rather than labeling it "AI-generated". Stored as its
/// raw string for SwiftData / CloudKit; `.aiGenerated` is the default so existing summaries are
/// unaffected.
enum SummaryAuthorship: String, Codable, Sendable, CaseIterable {
    /// Produced by the on-device summarizer (Apple Intelligence) — the default for every summary.
    case aiGenerated
    /// AI-seeded, then edited by the user.
    case aiEdited
    /// Written by the user from scratch.
    case userWritten
}

// MARK: - Headnote-draft cleanup

extension GeneratedSummary {
    /// Deletes the dedicated headnote-draft summary a collection entry owns (Composer redesign): the
    /// `GeneratedSummary` pointed at by `entry.headnoteSummaryId` **when it carries `isHeadnoteDraft`**.
    /// Call before deleting the entry (or its collection) so an edited/regenerated headnote draft does
    /// not linger orphaned — and CloudKit-sync forever — after its only owner is gone. Drafts are
    /// excluded from every summary query (`isHeadnoteDraft`), so they are inert but would otherwise
    /// accumulate. The `isHeadnoteDraft` guard means a headnote pointed at a *real* document summary is
    /// never touched (that summary belongs to the document, not the entry).
    static func deleteHeadnoteDraft(for entry: CollectionEntry, in context: ModelContext) {
        guard let sid = entry.headnoteSummaryId else { return }
        let drafts = (try? context.fetch(FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { $0.id == sid && $0.isHeadnoteDraft }))) ?? []
        for draft in drafts { context.delete(draft) }
    }

    /// Deletes the headnote drafts owned by every entry of `collection` — call before deleting the
    /// whole collection (its entries are deleted without individually routing through
    /// `deleteHeadnoteDraft`).
    static func deleteHeadnoteDrafts(for collection: Collection, in context: ModelContext) {
        for entry in collection.documentEntries ?? [] {
            deleteHeadnoteDraft(for: entry, in: context)
        }
    }

    /// Duplicates the headnote-draft summary that `sourceEntry` owns (if any) into a new independent
    /// draft and points `copyEntry` at it — so a duplicated collection's headnotes are fully editable
    /// without touching the original's drafts (#300). If `sourceEntry.headnoteSummaryId` points at a
    /// *real* document summary (not a draft), it is left shared: that summary belongs to the document,
    /// so the entry-field copy's identical id is correct.
    /// **`sourceContentHash` is deliberately absent below.** A headnote draft is the reader's own
    /// text, collection-private, and excluded from the review counts — it does not describe a
    /// version of the document in the sense the field means, so a copy must not invent one.
    static func duplicateHeadnoteDraft(from sourceEntry: CollectionEntry,
                                       to copyEntry: CollectionEntry,
                                       in context: ModelContext) {
        guard let sid = sourceEntry.headnoteSummaryId else { return }
        let drafts = (try? context.fetch(FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { $0.id == sid && $0.isHeadnoteDraft }))) ?? []
        guard let draft = drafts.first else { return }
        let copyDraft = GeneratedSummary(
            documentId: draft.documentId,
            volumeId: draft.volumeId,
            promptId: draft.promptId,
            responseText: draft.responseText,
            responseFormat: draft.responseFormat,
            wasChunked: draft.wasChunked,
            projectId: draft.projectId,
            authorship: draft.authorship ?? .aiGenerated,
            isHeadnoteDraft: true)
        context.insert(copyDraft)
        copyEntry.headnoteSummaryId = copyDraft.id
    }
}

// MARK: - Index push selection (R-5 P3b-1)

extension GeneratedSummary {
    /// The one summary per document whose text belongs in the FTS5 `summary_text` column.
    ///
    /// The column holds ONE text per document and the two push loops — boot reconcile and
    /// post-download — used to write every summary in fetch order, so whichever the store returned
    /// last won: search could rank a superseded summary, or a collection-private headnote draft,
    /// above the newest AI summary of the current text. This picks the newest non-draft per
    /// document: `createdAt` descending (nil last — rows synced from before the field existed),
    /// then `lastModified` descending, then `id` so the choice is total and stable.
    static func newestNonDraftPerDocument(_ summaries: [GeneratedSummary]) -> [GeneratedSummary] {
        var best: [String: GeneratedSummary] = [:]
        for s in summaries where !s.isHeadnoteDraft && !s.volumeId.isEmpty && !s.documentId.isEmpty {
            let key = "\(s.volumeId)/\(s.documentId)"
            if let current = best[key], !Self.ranksAbove(s, current) { continue }
            best[key] = s
        }
        return best.keys.sorted().compactMap { best[$0] }
    }

    /// The documents whose every summary is a headnote draft — the keys the selection above
    /// leaves out, and therefore the ones whose `summary_text` column must be CLEARED, not left.
    ///
    /// Before R-5 P3b-1 the push loops wrote every row, drafts included, so an existing install
    /// can hold a collection-private draft's words in the search column; a selection that merely
    /// skips those documents would freeze that text there forever. Blank ids are skipped.
    static func draftOnlyDocuments(_ summaries: [GeneratedSummary]) -> [(volumeId: String, documentId: String)] {
        var hasLive = Set<String>(), seen: [String: (String, String)] = [:]
        for s in summaries where !s.volumeId.isEmpty && !s.documentId.isEmpty {
            let key = "\(s.volumeId)/\(s.documentId)"
            seen[key] = (s.volumeId, s.documentId)
            if !s.isHeadnoteDraft { hasLive.insert(key) }
        }
        return seen.keys.sorted().filter { !hasLive.contains($0) }.map { (seen[$0]!.0, seen[$0]!.1) }
    }

    /// Strict "a should replace b" order for the selection above.
    ///
    /// Made non-private in R-5 P3b-6 so the document carousel shows the same summary this rule
    /// calls newest. The two disagreed: `DocumentViewModel.loadSummaries` ordered on `lastModified`
    /// alone, which is a SAVE stamp — `ModelModificationStamper` bumps it on every changed model,
    /// and two bulk paths rewrite summaries for unrelated reasons (`SummarizationPromptSeeder`
    /// repointing a duplicate prompt, `ProjectAdminService.merge` rewriting a project id). So a
    /// prompt de-duplication could silently reorder a reader's carousel while search went on
    /// naming a different summary as the newest. `createdAt` is never stamped.
    static func ranksAbove(_ a: GeneratedSummary, _ b: GeneratedSummary) -> Bool {
        let ca = a.createdAt ?? .distantPast, cb = b.createdAt ?? .distantPast
        if ca != cb { return ca > cb }
        let la = a.lastModified ?? .distantPast, lb = b.lastModified ?? .distantPast
        if la != lb { return la > lb }
        return a.id.uuidString < b.id.uuidString
    }
}
