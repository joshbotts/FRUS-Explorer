// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CryptoKit
import Foundation
import SwiftData

// MARK: - CloudKitSchemaInventory

/// The checked-in inventory of everything this build mirrors into CloudKit, plus the marker
/// recording how much of it has been promoted to the **Production** schema (Wave R-7).
///
/// ## Why this exists
/// `Planning/Completed/188-189-Tester-Feedback-Build28-Plan.md:158` specified "a startup log line if the
/// installed model set is newer than a known-deployed marker, so a future undeployed-schema
/// regression is caught before shipping." It was never built. Issue #488 **is** that regression:
/// build 35 added four CloudKit identifiers — `CD_ProjectLeadEntry`,
/// `CD_Project.CD_leadAxisWeights`, `CD_Project.CD_defaultUserTagIds`,
/// `CD_Collection.CD_includeProjectProvenance` — the Production schema was never promoted, and
/// CloudKit export failed for every user on that build. The owner had to diagnose it from the
/// CloudKit Console because the app could not describe its own failure.
///
/// ## What an "identifier" is
/// The strings here are CloudKit's own vocabulary, exactly as the CloudKit Console shows them and
/// exactly as #488 was eventually described: `CD_<RecordType>` for a mirrored `@Model`, and
/// `CD_<RecordType>.CD_<field>` for one of its mirrored properties. SwiftData's
/// `NSPersistentCloudKitContainer` derives both from the Core Data entity/attribute names, which
/// is what ``mirroredIdentifiers(of:)`` reads back out of a live `Schema`.
///
/// **Fields, not just record types.** Three of #488's four identifiers were *new fields on
/// existing types*, so a record-type-only inventory would have caught one quarter of it. That is
/// the whole reason this list is property-grained and therefore long.
///
/// ## The two halves, and why they are separate
/// - ``installedIdentifiers`` is a *machine-checkable* fact about this build.
///   `FRUSExplorerTests/CloudKitSchemaInventoryTests` rebuilds it from
///   `ModelContainer.frusModelTypes` and fails — with the deploy checklist in the message — the
///   moment the two disagree. Adding or removing a `@Model`, or a stored property on one, cannot
///   pass the suite silently.
/// - The deploy marker (``deployedThroughBuild`` … ``identifiersAwaitingDeploy``) is an
///   *owner-attested* fact about the CloudKit container. No test can verify it: nothing in this
///   process can see the Production schema. What the test *can* do — and does — is make the claim
///   impossible to skip, by pinning `installed − awaiting` to a count and a digest. Add an
///   identifier and you must either list it in ``identifiersAwaitingDeploy`` (honest: not
///   deployed yet) or restate the baseline (a claim that you deployed it). Both are explicit acts
///   in the diff; neither happens by accident.
///
/// ## Cost at launch
/// The runtime check is `identifiersAwaitingDeploy.isEmpty` — one already-materialised array
/// literal. Nothing is hashed, no `Schema` is walked, and ``installedIdentifiers`` is not touched
/// unless something is pending. The expensive comparison against the real schema happens in the
/// test suite, once, on a developer's machine.
///
/// Version history:
///   1.0 — Wave R-7: initial implementation
///   1.1 — Wave R-2a: `ExportHistoryEntry`'s seven identifiers added to the inventory **and** to
///          ``identifiersAwaitingDeploy`` — the gate fired on the model change, as designed, and
///          the deploy has not happened yet. The baseline count and digest are unchanged, which
///          is the point: `installed − awaiting` still describes Production.
///   1.2 — Archive Visits Phase 2: the three plan record types' 32 identifiers added to the
///          inventory **and** to ``identifiersAwaitingDeploy`` (boarding the reserved W-4+W-5
///          promotion). Baseline count and digest unchanged — `installed − awaiting` still
///          describes Production.
enum CloudKitSchemaInventory {

    // MARK: - The installed model set (pinned by CloudKitSchemaInventoryTests)

    /// Every CloudKit identifier the model set in `ModelContainer.frusModelTypes` mirrors, sorted.
    ///
    /// Do not hand-edit. When the schema changes, `CloudKitSchemaInventoryTests` prints the
    /// replacement list; paste it wholesale so the diff shows exactly what CloudKit gained or lost.
    static let installedIdentifiers: [String] = [
        "CD_ArchiveVisitDocument",
        "CD_ArchiveVisitDocument.CD_createdAt",
        "CD_ArchiveVisitDocument.CD_documentKey",
        "CD_ArchiveVisitDocument.CD_id",
        "CD_ArchiveVisitDocument.CD_includeExternalRefs",
        "CD_ArchiveVisitDocument.CD_includeSource",
        "CD_ArchiveVisitDocument.CD_lastModified",
        "CD_ArchiveVisitDocument.CD_plan",
        "CD_ArchiveVisitDocument.CD_planId",
        "CD_ArchiveVisitDocument.CD_stateData",
        "CD_ArchiveVisitPlan",
        "CD_ArchiveVisitPlan.CD_createdAt",
        "CD_ArchiveVisitPlan.CD_deliverableTogglesData",
        "CD_ArchiveVisitPlan.CD_documents",
        "CD_ArchiveVisitPlan.CD_id",
        "CD_ArchiveVisitPlan.CD_inquiryText",
        "CD_ArchiveVisitPlan.CD_lastModified",
        "CD_ArchiveVisitPlan.CD_name",
        "CD_ArchiveVisitPlan.CD_projectIds",
        "CD_ArchiveVisitPlan.CD_targets",
        "CD_ArchiveVisitPlan.CD_tiersData",
        "CD_ArchiveVisitTarget",
        "CD_ArchiveVisitTarget.CD_createdAt",
        "CD_ArchiveVisitTarget.CD_id",
        "CD_ArchiveVisitTarget.CD_included",
        "CD_ArchiveVisitTarget.CD_lastModified",
        "CD_ArchiveVisitTarget.CD_plan",
        "CD_ArchiveVisitTarget.CD_planId",
        "CD_ArchiveVisitTarget.CD_stateData",
        "CD_ArchiveVisitTarget.CD_targetKey",
        "CD_ArchiveVisitTarget.CD_tierId",
        "CD_ArchiveVisitTarget.CD_userNote",
        "CD_Collection",
        "CD_Collection.CD_applyHighlights",
        "CD_Collection.CD_authorLine",
        "CD_Collection.CD_createdAt",
        "CD_Collection.CD_defaultBodyDepth",
        "CD_Collection.CD_defaultIncludeHeadnote",
        "CD_Collection.CD_documentEntries",
        "CD_Collection.CD_footnoteStyle",
        "CD_Collection.CD_id",
        "CD_Collection.CD_includeColophon",
        "CD_Collection.CD_includeFootnotes",
        "CD_Collection.CD_includeMethodAppendix",
        "CD_Collection.CD_includeNotes",
        "CD_Collection.CD_includeProjectProvenance",
        "CD_Collection.CD_includeSourceNote",
        "CD_Collection.CD_includeWordCloud",
        "CD_Collection.CD_introductionRichText",
        "CD_Collection.CD_introductionText",
        "CD_Collection.CD_lastModified",
        "CD_Collection.CD_name",
        "CD_Collection.CD_note",
        "CD_Collection.CD_projectIds",
        "CD_Collection.CD_savedSearchId",
        "CD_Collection.CD_subtitle",
        "CD_Collection.CD_summaryPromptId",
        "CD_Collection.CD_tocStyle",
        "CD_CollectionEntry",
        "CD_CollectionEntry.CD_applyHighlightsOverride",
        "CD_CollectionEntry.CD_bodyDepthOverride",
        "CD_CollectionEntry.CD_collection",
        "CD_CollectionEntry.CD_collectionId",
        "CD_CollectionEntry.CD_createdAt",
        "CD_CollectionEntry.CD_documentId",
        "CD_CollectionEntry.CD_excerptColorTag",
        "CD_CollectionEntry.CD_excerptEnd",
        "CD_CollectionEntry.CD_excerptRenderingVersion",
        "CD_CollectionEntry.CD_excerptStart",
        "CD_CollectionEntry.CD_generatedBlockType",
        "CD_CollectionEntry.CD_headnoteSummaryId",
        "CD_CollectionEntry.CD_id",
        "CD_CollectionEntry.CD_includeFootnotesOverride",
        "CD_CollectionEntry.CD_includeHeadnote",
        "CD_CollectionEntry.CD_includeNotesOverride",
        "CD_CollectionEntry.CD_includeRelatedDocuments",
        "CD_CollectionEntry.CD_includeSourceNoteOverride",
        "CD_CollectionEntry.CD_kind",
        "CD_CollectionEntry.CD_lastModified",
        "CD_CollectionEntry.CD_level",
        "CD_CollectionEntry.CD_researchNoteId",
        "CD_CollectionEntry.CD_richText",
        "CD_CollectionEntry.CD_selectedHighlightIds",
        "CD_CollectionEntry.CD_selectedNoteIds",
        "CD_CollectionEntry.CD_sortOrder",
        "CD_CollectionEntry.CD_summaryPromptIdOverride",
        "CD_CollectionEntry.CD_text",
        "CD_CollectionEntry.CD_titleOverride",
        "CD_CollectionEntry.CD_volumeId",
        "CD_CustomVolumeScope",
        "CD_CustomVolumeScope.CD_createdAt",
        "CD_CustomVolumeScope.CD_id",
        "CD_CustomVolumeScope.CD_lastModified",
        "CD_CustomVolumeScope.CD_name",
        "CD_CustomVolumeScope.CD_volumeIds",
        "CD_DocumentHighlight",
        "CD_DocumentHighlight.CD_colorTag",
        "CD_DocumentHighlight.CD_createdAt",
        "CD_DocumentHighlight.CD_documentId",
        "CD_DocumentHighlight.CD_endOffset",
        "CD_DocumentHighlight.CD_id",
        "CD_DocumentHighlight.CD_noteId",
        "CD_DocumentHighlight.CD_renderingVersion",
        "CD_DocumentHighlight.CD_selectedText",
        "CD_DocumentHighlight.CD_startOffset",
        "CD_DocumentHighlight.CD_volumeId",
        "CD_DocumentTagAssignment",
        "CD_DocumentTagAssignment.CD_createdAt",
        "CD_DocumentTagAssignment.CD_documentId",
        "CD_DocumentTagAssignment.CD_id",
        "CD_DocumentTagAssignment.CD_tagId",
        "CD_DocumentTagAssignment.CD_volumeId",
        "CD_ExportHistoryEntry",
        "CD_ExportHistoryEntry.CD_collectionName",
        "CD_ExportHistoryEntry.CD_documentCount",
        "CD_ExportHistoryEntry.CD_exportedAt",
        "CD_ExportHistoryEntry.CD_format",
        "CD_ExportHistoryEntry.CD_id",
        "CD_ExportHistoryEntry.CD_projectId",
        "CD_GeneratedSummary",
        "CD_GeneratedSummary.CD_authorship",
        "CD_GeneratedSummary.CD_createdAt",
        "CD_GeneratedSummary.CD_documentId",
        "CD_GeneratedSummary.CD_id",
        "CD_GeneratedSummary.CD_isHeadnoteDraft",
        "CD_GeneratedSummary.CD_lastModified",
        "CD_GeneratedSummary.CD_projectId",
        "CD_GeneratedSummary.CD_promptId",
        "CD_GeneratedSummary.CD_responseFormat",
        "CD_GeneratedSummary.CD_responseText",
        "CD_GeneratedSummary.CD_volumeId",
        "CD_GeneratedSummary.CD_wasChunked",
        "CD_PersonClusterOverride",
        "CD_PersonClusterOverride.CD_createdAt",
        "CD_PersonClusterOverride.CD_id",
        "CD_PersonClusterOverride.CD_kind",
        "CD_PersonClusterOverride.CD_refA",
        "CD_PersonClusterOverride.CD_refB",
        "CD_PersonClusterOverride.CD_volumeIdA",
        "CD_PersonClusterOverride.CD_volumeIdB",
        "CD_Project",
        "CD_Project.CD_createdAt",
        "CD_Project.CD_defaultCountryTagIds",
        "CD_Project.CD_defaultDateRangeEnd",
        "CD_Project.CD_defaultDateRangeStart",
        "CD_Project.CD_defaultSubjectTagIds",
        "CD_Project.CD_defaultUserTagIds",
        "CD_Project.CD_id",
        "CD_Project.CD_lastModified",
        "CD_Project.CD_leadAxisWeights",
        "CD_Project.CD_name",
        "CD_Project.CD_researchQuestion",
        "CD_ProjectLeadEntry",
        "CD_ProjectLeadEntry.CD_aggregateScore",
        "CD_ProjectLeadEntry.CD_contributingSeedKeys",
        "CD_ProjectLeadEntry.CD_dismissed",
        "CD_ProjectLeadEntry.CD_documentId",
        "CD_ProjectLeadEntry.CD_documentNumber",
        "CD_ProjectLeadEntry.CD_firstSurfacedAt",
        "CD_ProjectLeadEntry.CD_header",
        "CD_ProjectLeadEntry.CD_id",
        "CD_ProjectLeadEntry.CD_isEditorialNote",
        "CD_ProjectLeadEntry.CD_lastComputedAt",
        "CD_ProjectLeadEntry.CD_projectId",
        "CD_ProjectLeadEntry.CD_volumeId",
        "CD_ReadingHistoryEntry",
        "CD_ReadingHistoryEntry.CD_accessedAt",
        "CD_ReadingHistoryEntry.CD_displayTitle",
        "CD_ReadingHistoryEntry.CD_documentId",
        "CD_ReadingHistoryEntry.CD_id",
        "CD_ReadingHistoryEntry.CD_projectId",
        "CD_ReadingHistoryEntry.CD_volumeId",
        "CD_ResearchNote",
        "CD_ResearchNote.CD_bodyText",
        "CD_ResearchNote.CD_createdAt",
        "CD_ResearchNote.CD_documentId",
        "CD_ResearchNote.CD_id",
        "CD_ResearchNote.CD_lastModified",
        "CD_ResearchNote.CD_projectIds",
        "CD_ResearchNote.CD_selectedSummaryIds",
        "CD_ResearchNote.CD_userTagIds",
        "CD_ResearchNote.CD_volumeId",
        "CD_SavedSearch",
        "CD_SavedSearch.CD_booleanModeRaw",
        "CD_SavedSearch.CD_createdAt",
        "CD_SavedSearch.CD_dateRangeEnd",
        "CD_SavedSearch.CD_dateRangeStart",
        "CD_SavedSearch.CD_documentTypeFilterRaw",
        "CD_SavedSearch.CD_excludedTermsCSV",
        "CD_SavedSearch.CD_id",
        "CD_SavedSearch.CD_name",
        "CD_SavedSearch.CD_parametersData",
        "CD_SavedSearch.CD_personRef",
        "CD_SavedSearch.CD_phraseText",
        "CD_SavedSearch.CD_prefixWildcard",
        "CD_SavedSearch.CD_queryText",
        "CD_SavedSearch.CD_scopeFlags",
        "CD_SavedSearch.CD_sortOrder",
        "CD_SavedSearch.CD_subjectTagIdsCSV",
        "CD_SearchHistoryEntry",
        "CD_SearchHistoryEntry.CD_appliedCorpusId",
        "CD_SearchHistoryEntry.CD_executedAt",
        "CD_SearchHistoryEntry.CD_fetchLimit",
        "CD_SearchHistoryEntry.CD_id",
        "CD_SearchHistoryEntry.CD_indexedVolumeCount",
        "CD_SearchHistoryEntry.CD_loadedCount",
        "CD_SearchHistoryEntry.CD_matchCount",
        "CD_SearchHistoryEntry.CD_projectId",
        "CD_SearchHistoryEntry.CD_queryText",
        "CD_SearchHistoryEntry.CD_renderedExpression",
        "CD_SearchHistoryEntry.CD_resultCount",
        "CD_SearchHistoryEntry.CD_scopeSignature",
        "CD_SummarizationPrompt",
        "CD_SummarizationPrompt.CD_createdAt",
        "CD_SummarizationPrompt.CD_id",
        "CD_SummarizationPrompt.CD_isStandard",
        "CD_SummarizationPrompt.CD_lastModified",
        "CD_SummarizationPrompt.CD_name",
        "CD_SummarizationPrompt.CD_promptText",
        "CD_SummarizationPrompt.CD_responseFormat",
        "CD_SummarizationPrompt.CD_schema",
        "CD_SyncedPreferences",
        "CD_SyncedPreferences.CD_citationStyleRaw",
        "CD_SyncedPreferences.CD_createdAt",
        "CD_SyncedPreferences.CD_defaultDocumentModeRaw",
        "CD_SyncedPreferences.CD_researchLoggingEnabled",
        "CD_SyncedPreferences.CD_updatedAt",
        "CD_SyncedPreferences.CD_wcExcludeBoilerplate",
        "CD_SyncedPreferences.CD_wcFilterMarkings",
        "CD_SyncedPreferences.CD_wcFoldPlurals",
        "CD_SyncedPreferences.CD_wcGlobalStopwordsJSON",
        "CD_SyncedPreferences.CD_wcLensStopwordsJSON",
        "CD_SyncedPreferences.CD_wcMinCount",
        "CD_SyncedPreferences.CD_wcMinLength",
        "CD_UserTag",
        "CD_UserTag.CD_createdAt",
        "CD_UserTag.CD_id",
        "CD_UserTag.CD_lastModified",
        "CD_UserTag.CD_name",
        "CD_WorkingCorpus",
        "CD_WorkingCorpus.CD_capturedAt",
        "CD_WorkingCorpus.CD_createdAt",
        "CD_WorkingCorpus.CD_documentKeys",
        "CD_WorkingCorpus.CD_id",
        "CD_WorkingCorpus.CD_indexedVolumeCountAtCapture",
        "CD_WorkingCorpus.CD_lastModified",
        "CD_WorkingCorpus.CD_name",
        "CD_WorkingCorpus.CD_sourceDescription",
        "CD_WorkingCorpus.CD_sourceQuery",
        "CD_WorkingCorpus.CD_totalMatchCountAtCapture",
        "CD_WorkingCorpus.CD_wasTruncatedAtCapture",
    ]

    // MARK: - The deploy marker (owner-attested)

    /// The build at which the Production CloudKit schema was last promoted.
    ///
    /// Build 37. Five promotions are recorded here. Issue #488's closing comment — *"Resolved by
    /// deploying the missing CloudKit schema"* (2026-07-26) — brought Production level with the
    /// build-35 additions. The second, the same day, promoted `CD_ExportHistoryEntry` and its six
    /// fields for Wave R-2a. The third (2026-07-31) promoted `CD_WorkingCorpus` and its nine fields
    /// for M-1 — again after a Development build saved a real record, since CloudKit creates a
    /// record type only when one is first written, the trap that made #488 possible. The fourth
    /// (also 2026-07-31) promoted `CD_WorkingCorpus`'s two typed capture-truncation fields, which
    /// are what let four corpus-scoped sentences stop asserting completeness they could not know —
    /// a `String` cannot be tested in a `guard`, and parsing one to recover a boolean fails open.
    /// The fifth (2026-08-01, build 37) promoted M-2's seven `CD_SearchHistoryEntry` fields, which
    /// are what let a recorded search be reproduced: the expression it executed, the scope it ran
    /// under, the indexed-volume denominator, and a count that distinguishes a total from a floor.
    /// The sixth (2026-08-01, build 37) promoted `CD_Collection.CD_includeMethodAppendix`. The
    /// seventh (2026-08-08, build 40) promoted `CD_SavedSearch.CD_parametersData` — one field that
    /// ends the SavedSearch field-drop class outright (#756), rather than the eight columns an
    /// enumerate-the-fields fix would have cost and re-cost.
    static let deployedThroughBuild = "40"

    /// The date of that promotion, for the Settings row and for anyone reading the CloudKit
    /// Console's history alongside this file.
    static let deployedOn = "2026-08-08"

    /// How many identifiers **this build mirrors that are attested deployed**. Pinned by the
    /// test against `installedIdentifiers.count - identifiersAwaitingDeploy.count`, so the
    /// baseline cannot drift from the inventory unnoticed.
    ///
    /// ## R-2b changed what this number is a claim ABOUT, and the difference matters
    /// It fell 234 → 219 without a Production deploy, which every previous change to it
    /// implied. That is correct, because **CloudKit Production schema is append-only**: a
    /// record type cannot be deleted from it. Retiring `ResearchSession`/`SessionEvent` stops
    /// the app mirroring them; the 15 identifiers stay in Production for ever, orphaned and
    /// harmless, carrying whatever rows users' devices already pushed.
    ///
    /// So this is a SUBSET claim — every identifier this build mirrors is deployed — not an
    /// equality claim about Production's contents. A future ADDITION still needs the full R-7
    /// checklist; a future removal needs only this number and the digest, and must NOT bump
    /// `deployedThroughBuild`, which would assert a promotion that never happened.
    static let deployedIdentifierCount = 219

    /// SHA-256 (hex) of the newline-joined deployed baseline. The count alone would not catch a
    /// rename, an add-and-remove in the same change, or a paste that dropped one line and gained
    /// another.
    static let deployedIdentifierDigest =
        "d1297540c9adacce4e45cc2a3597f09c6e2b6d5cb75d5d6c7fb0c7918bac6de0"

    /// Identifiers present in this build that have **not** been promoted to Production.
    ///
    /// Empty means the Production schema matches this build. Non-empty means CloudKit will reject
    /// records carrying them — the #488 failure mode — and the app says so at launch and in
    /// Settings ▸ Data & Recovery.
    ///
    /// **This list is also an interlock, not only a notice.** `ResearchTrailMigration` refuses to
    /// run while any identifier here belongs to a record type it writes, because that pass writes
    /// replacements and deletes their sources in one call: CloudKit would take the deletions and
    /// reject the writes, and the data would be gone on the next device. Anything else that both
    /// writes an undeployed type and destroys its source should consult this the same way.
    ///
    /// Populated by the developer who changes the schema; cleared by whoever runs
    /// CloudKit Dashboard → Schema → **Deploy Schema Changes to Production**.
    ///
    /// **Wave R-2b** removed `ResearchSession`/`SessionEvent` — 15 identifiers — and added
    /// nothing, so this list is untouched by it. A removal cannot await a deploy: there is no
    /// Production change to promote (the schema is append-only), and the two types' identifiers
    /// remain in Production unmirrored. See `deployedIdentifierCount` for what that does to the
    /// baseline's meaning.
    static let identifiersAwaitingDeploy: [String] = [
        // Archive Visits Phase 2 — the three plan record types and their 29 fields, boarding
        // the reserved W-4+W-5 promotion (the owner's schema-timing decision). Until that
        // deploy, Production rejects records carrying these; the app reports the holding state
        // at launch and in Settings ▸ Data & Recovery ▸ iCloud Schema. Owner steps: exercise
        // each type once on a Development build signed into iCloud (create a plan, seed a
        // document, tier a target — CloudKit creates a record type only when one is first
        // written, the trap that made #488 possible), then CloudKit Dashboard → Schema →
        // Deploy Schema Changes to Production; then clear this list, restate the baseline
        // count + digest the suite prints, and bump `deployedThroughBuild` / `deployedOn`.
        //
        // (Promoted 2026-08-08, build 40, the SEVENTH promotion: `CD_SavedSearch.CD_parametersData`
        // — #756's complete SearchParameters snapshot; one archived value instead of eight
        // enumerated columns, which is what makes the field-drop class unrepresentable.)
        "CD_ArchiveVisitDocument",
        "CD_ArchiveVisitDocument.CD_createdAt",
        "CD_ArchiveVisitDocument.CD_documentKey",
        "CD_ArchiveVisitDocument.CD_id",
        "CD_ArchiveVisitDocument.CD_includeExternalRefs",
        "CD_ArchiveVisitDocument.CD_includeSource",
        "CD_ArchiveVisitDocument.CD_lastModified",
        "CD_ArchiveVisitDocument.CD_plan",
        "CD_ArchiveVisitDocument.CD_planId",
        "CD_ArchiveVisitDocument.CD_stateData",
        "CD_ArchiveVisitPlan",
        "CD_ArchiveVisitPlan.CD_createdAt",
        "CD_ArchiveVisitPlan.CD_deliverableTogglesData",
        "CD_ArchiveVisitPlan.CD_documents",
        "CD_ArchiveVisitPlan.CD_id",
        "CD_ArchiveVisitPlan.CD_inquiryText",
        "CD_ArchiveVisitPlan.CD_lastModified",
        "CD_ArchiveVisitPlan.CD_name",
        "CD_ArchiveVisitPlan.CD_projectIds",
        "CD_ArchiveVisitPlan.CD_targets",
        "CD_ArchiveVisitPlan.CD_tiersData",
        "CD_ArchiveVisitTarget",
        "CD_ArchiveVisitTarget.CD_createdAt",
        "CD_ArchiveVisitTarget.CD_id",
        "CD_ArchiveVisitTarget.CD_included",
        "CD_ArchiveVisitTarget.CD_lastModified",
        "CD_ArchiveVisitTarget.CD_plan",
        "CD_ArchiveVisitTarget.CD_planId",
        "CD_ArchiveVisitTarget.CD_stateData",
        "CD_ArchiveVisitTarget.CD_targetKey",
        "CD_ArchiveVisitTarget.CD_tierId",
        "CD_ArchiveVisitTarget.CD_userNote",
    ]

    // MARK: - Derived state

    /// `true` when every mirrored identifier in this build has been promoted to Production.
    static var isProductionSchemaCurrent: Bool { identifiersAwaitingDeploy.isEmpty }

    /// The identifiers the Production schema is attested to carry: the installed set minus
    /// whatever is still awaiting a deploy.
    static var deployedBaseline: [String] {
        let pending = Set(identifiersAwaitingDeploy)
        return installedIdentifiers.filter { !pending.contains($0) }
    }

    /// How many `@Model` types this build mirrors — the count the version-history block in
    /// `ModelContainer+FRUS.swift` used to carry by hand, and got wrong (it said 16 for a list of
    /// 18). Derived from the inventory so it can no longer drift.
    static var recordTypeCount: Int {
        installedIdentifiers.filter { !$0.contains(".") }.count
    }

    /// How many mirrored **fields** this build carries — the inventory minus its record-type
    /// rows. Kept distinct from `installedIdentifiers.count`, which counts both and would
    /// overstate the field total by the number of record types.
    static var fieldCount: Int { installedIdentifiers.count - recordTypeCount }

    // MARK: - Reading a live schema

    /// The CloudKit identifiers a `Schema` mirrors: one `CD_<Entity>` per entity plus one
    /// `CD_<Entity>.CD_<property>` per stored, non-transient property, sorted.
    ///
    /// Prefers each property's `originalName` — the persisted Core Data name, which is what
    /// CloudKit mirrors — so a future `@Attribute(originalName:)` rename reports the name the
    /// server actually holds rather than the Swift one. **Measured, not assumed:** SwiftData
    /// leaves `originalName` an empty string unless a rename is declared, so an empty value falls
    /// back to `name`. Without that fallback every field in this app reads as `CD_`.
    ///
    /// Called by the test suite, not at launch; see the type's "Cost at launch" note.
    static func mirroredIdentifiers(of schema: Schema) -> [String] {
        var identifiers: [String] = []
        for entity in schema.entities {
            let recordType = "CD_\(entity.name)"
            identifiers.append(recordType)
            for property in entity.properties where !property.isTransient {
                let field = property.originalName.isEmpty ? property.name : property.originalName
                identifiers.append("\(recordType).CD_\(field)")
            }
        }
        return identifiers.sorted()
    }

    /// SHA-256 hex digest of a newline-joined identifier list. Stable across runs and platforms,
    /// which is what makes it usable as a checked-in baseline.
    static func digest(of identifiers: [String]) -> String {
        let joined = identifiers.joined(separator: "\n")
        let hash = SHA256.hash(data: Data(joined.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - The startup signal

    /// The startup line specified in the build-28 plan and never built until Wave R-7.
    ///
    /// Called from `makeFRUSContainer()` on the CloudKit-enabled path only — a local-only or
    /// test-host container never talks to CloudKit, so its deploy state is not a fact about
    /// anything. Deliberately **not** `#if DEBUG` in the pending case: an undeployed schema is a
    /// release defect, and the console of a TestFlight device is where it would otherwise have to
    /// be noticed.
    static func logDeployStateIfNeeded() {
        guard !isProductionSchemaCurrent else {
            #if DEBUG
            print("[CloudKitSchema] Production schema current — deployed through build "
                  + "\(deployedThroughBuild) (\(deployedOn))")
            #endif
            return
        }
        print("[CloudKitSchema] ⚠️  The installed model set is NEWER than the deployed CloudKit "
              + "schema. Last deploy: build \(deployedThroughBuild) (\(deployedOn)).")
        print("[CloudKitSchema] ⚠️  Awaiting Production deploy: "
              + identifiersAwaitingDeploy.joined(separator: ", "))
        print("[CloudKitSchema] ⚠️  Records carrying these will fail to sync (this is #488). "
              + "CloudKit Dashboard → Schema → Deploy Schema Changes to Production.")
    }
}
