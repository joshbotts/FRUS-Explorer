// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - PromptTemplate

/// A static template definition used to seed standard `SummarizationPrompt` records
/// and to pre-populate the prompt editor when the user selects "Use Template".
struct PromptTemplate: Identifiable, Sendable {
    let id: UUID
    let name: String
    let promptText: String
    /// Non-empty for structured templates; empty for the general template.
    let fields: [StructuredSummarySchema.Field]

    var responseFormat: ResponseFormat {
        fields.isEmpty
            ? .general
            : .structured(schema: StructuredSummarySchema(fields: fields))
    }

    var schema: StructuredSummarySchema? {
        fields.isEmpty ? nil : StructuredSummarySchema(fields: fields)
    }
}

// MARK: - SummarizationPromptSeeder

/// Seeds standard `SummarizationPrompt` records into SwiftData on first launch.
///
/// Inserts the standard general-purpose prompt and the seven structured-schema
/// templates approved for Session 20. All seeded records have `isStandard = true`.
///
/// ## Idempotency
/// `seed(in:)` checks by prompt name before inserting each template so it is safe
/// to call on multiple platforms sharing the same CloudKit container. Only templates
/// whose names are not already present in the store are inserted. This prevents
/// the duplicate-prompt symptom that arose when both Mac and iOS seeded before
/// CloudKit could sync the first batch.
///
/// After inserting, `seed(in:)` runs a deduplication pass that removes any surplus
/// standard prompts that share a name (keeping the oldest by `createdAt`). This
/// repairs any duplicates that were created before this fix was deployed.
///
/// ## Name idempotency is not text idempotency (#1329)
/// The name check above decides whether a row is CREATED. It says nothing about what the row
/// says, so for four years of releases a template's wording was reachable only by a fresh
/// install: editing a literal in this file left every existing device on the text it was seeded
/// with, because generation reads the stored row. `refreshStandardPrompts(context:)` closes that
/// — it rewrites `promptText`, `responseFormat` and `schema` on a standard row whose text has
/// fallen behind its template — and `seed(in:)` runs it after the collapse.
///
/// ## Log prefix
/// `[SummarizationPromptSeeder]`
///
/// Version history:
///   1.0 — Session 20: initial implementation
///   1.1 — Session 75: per-name idempotency check + deduplication pass to fix
///          CloudKit sync race that produced duplicate standard prompts when both
///          Mac and iOS seeded before the first batch had synced.
///   1.2 — #1329: the four templates that ask about people now ask for names, titles and
///          offices AS THE DOCUMENT STATES THEM, and `refreshStandardPrompts(context:)`
///          carries a reworded template onto rows that were seeded before it. Without the
///          refresh the reword would have reached only fresh installs.
enum SummarizationPromptSeeder {

    // MARK: - Standard Templates (public for prompt editor use)

    /// The full set of standard templates: 1 general + 7 structured.
    static let standardTemplates: [PromptTemplate] = [
        generalTemplate,
        meetingRecordTemplate,
        policyDecisionTemplate,
        analyticalReportTemplate,
        diplomaticExchangeTemplate,
        crisisEventTemplate,
        individualRoleTraceTemplate,
        relevanceAssessmentTemplate,
    ]

    // MARK: - Seed

    /// Inserts missing standard prompts and deduplicates any existing duplicates.
    ///
    /// - Each template is only inserted if no standard prompt with the same name
    ///   already exists in the store.
    /// - After insertion, duplicate standard prompts (same name) are resolved by
    ///   keeping the oldest record and deleting the rest.
    ///
    /// Creates its own `ModelContext` from the supplied container.
    @MainActor
    static func seed(in container: ModelContainer) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SummarizationPrompt>(
            predicate: #Predicate { $0.isStandard == true }
        )
        let existing = (try? context.fetch(descriptor)) ?? []

        // Build the set of names already in the store.
        let existingNames = Set(existing.map(\.name))

        // Insert any template whose name is not already present.
        var insertCount = 0
        for template in standardTemplates {
            guard !existingNames.contains(template.name) else { continue }
            let prompt = SummarizationPrompt(
                name: template.name,
                promptText: template.promptText,
                responseFormat: template.responseFormat,
                isStandard: true,
                schema: template.schema
            )
            context.insert(prompt)
            insertCount += 1
        }

        let deleteCount = collapseDuplicates(context: context)
        // #1329: after the collapse, so it never rewrites a row that is about to be deleted.
        // It saves its own work, so a refresh-only run is durable even though the guard below
        // returns early on it.
        let refreshCount = refreshStandardPrompts(context: context)

        guard insertCount > 0 || deleteCount > 0 || refreshCount > 0 else {
            #if DEBUG
            print("[SummarizationPromptSeeder] All standard prompts present — nothing to do")
            #endif
            return
        }

        do {
            try context.save()
            #if DEBUG
            if insertCount > 0 {
                print("[SummarizationPromptSeeder] Seeded \(insertCount) standard prompt(s)")
            }
            #endif
        } catch {
            #if DEBUG
            print("[SummarizationPromptSeeder] Save failed: \(error)")
            #endif
        }
    }

    // MARK: - Duplicate collapse (#561)

    /// Collapses standard prompts that share a name, keeping one and re-pointing everything that
    /// referenced the others.
    ///
    /// ## Why this is separate from seeding, and why it runs again after import
    /// Seeding runs once per process, inside boot. **SwiftData's CloudKit initial import lands
    /// after that.** So on a second device the order is: boot → store empty → seed 8 → import
    /// delivers the first device's 8 → the user sees 16, and the pass that would have collapsed
    /// them already ran. Before this change the duplicates stayed visible for the whole session,
    /// collapsing only at the next cold launch — on macOS, potentially days.
    ///
    /// So the collapse is callable on its own, and `FRUSExplorerApp` invokes it from the debounced
    /// post-import block that already exists for exactly this class of problem (alongside
    /// `DuplicateRecordCleanup` and `OrphanedTagRepair`): a few seconds after imports go quiet,
    /// against a settled store rather than a partial one mid-sync.
    ///
    /// ## Why not `DuplicateRecordCleanup`
    /// That type collapses records that **are** the same record — same `id`, delivered twice. These
    /// are different records that *mean* the same thing: independently seeded on each device with
    /// different ids, identified only by name. Folding a name-keyed rule into an id-keyed type
    /// would blur what "duplicate" means there. The rule lives with the seeder that mints them.
    ///
    /// Labelled `context:` rather than `in:` to match `DuplicateRecordCleanup.run(context:)` and
    /// `OrphanedTagRepair.run(context:)`, which it is called beside.
    ///
    /// Saves when it deleted something, matching the contract its two neighbours already have —
    /// both `DuplicateRecordCleanup.run` and `OrphanedTagRepair.run` persist their own work. The
    /// debounced call site does not save, so a collapse that did not save here would be discarded
    /// and the duplicates would still be on screen.
    ///
    /// - Parameter context: the context to collapse in.
    /// - Returns: how many duplicates were deleted.
    @MainActor
    @discardableResult
    static func collapseDuplicates(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<SummarizationPrompt>(
            predicate: #Predicate { $0.isStandard == true }
        )
        guard let allStandard = try? context.fetch(descriptor) else { return 0 }

        var byName: [String: [SummarizationPrompt]] = [:]
        for prompt in allStandard { byName[prompt.name, default: []].append(prompt) }

        // id → the keeper it should point at, for every prompt about to be deleted.
        var remap: [UUID: UUID] = [:]
        var doomed: [SummarizationPrompt] = []
        for (_, group) in byName where group.count > 1 {
            let keeper = stableKeeper(group)
            for duplicate in group where duplicate.id != keeper.id {
                remap[duplicate.id] = keeper.id
                doomed.append(duplicate)
            }
        }
        guard !doomed.isEmpty else { return 0 }

        repointReferences(remap, in: context)
        for duplicate in doomed { context.delete(duplicate) }

        do {
            try context.save()
        } catch {
            // A failed save leaves the duplicates in place — visible, which is the right failure
            // for a cosmetic repair. The next import's debounce, or the next cold boot, retries.
            print("[SummarizationPromptSeeder] Collapse save failed: \(error)")
            return 0
        }
        // Deliberately NOT `#if DEBUG`: these are CloudKit-synced deletions that propagate to every
        // device, so the one line saying it happened should exist in a shipping build's log too.
        print("[SummarizationPromptSeeder] Collapsed \(doomed.count) duplicate standard prompt(s)")
        return doomed.count
    }

    /// The keeper for a duplicate group: earliest `createdAt`, tie-broken by id.
    ///
    /// The tiebreak is load-bearing rather than tidiness. Two devices run this independently, and
    /// if they ever chose *different* keepers they would delete each other's survivor and the
    /// prompt would vanish everywhere. `createdAt` alone does not decide it — a `nil` on both sides
    /// (legacy rows) leaves the comparison equal in both directions and the result depends on fetch
    /// order, which two devices need not share. Mirrors `DuplicateRecordCleanup.stableKeeper`.
    private static func stableKeeper(_ group: [SummarizationPrompt]) -> SummarizationPrompt {
        group.min { lhs, rhs in
            let l = lhs.createdAt ?? .distantFuture
            let r = rhs.createdAt ?? .distantFuture
            if l != r { return l < r }
            return lhs.id.uuidString < rhs.id.uuidString
        }!
    }

    /// Re-points everything that stores a prompt id at the keeper, before the duplicates go.
    ///
    /// **Three referrers, not one.** A summary remembers which prompt produced it; a collection
    /// stores a default prompt for its generated blocks; an entry can override that per row.
    /// Deleting a duplicate without re-pointing all three leaves a dangling id — a summary whose
    /// provenance no longer resolves, or a collection whose default silently falls back.
    private static func repointReferences(_ remap: [UUID: UUID], in context: ModelContext) {
        guard !remap.isEmpty else { return }

        for summary in (try? context.fetch(FetchDescriptor<GeneratedSummary>())) ?? [] {
            if let keeper = remap[summary.promptId] { summary.promptId = keeper }
        }
        for collection in (try? context.fetch(FetchDescriptor<Collection>())) ?? [] {
            if let current = collection.summaryPromptId, let keeper = remap[current] {
                collection.summaryPromptId = keeper
            }
        }
        for entry in (try? context.fetch(FetchDescriptor<CollectionEntry>())) ?? [] {
            if let current = entry.summaryPromptIdOverride, let keeper = remap[current] {
                entry.summaryPromptIdOverride = keeper
            }
        }
    }

    // MARK: - Standard-prompt refresh (#1329)

    /// Rewrites a standard prompt whose stored text no longer matches the template it was seeded
    /// from.
    ///
    /// ## Why this has to exist at all
    /// `seed(in:)` skips a template whose NAME is already present and never looks at what the row
    /// says. So editing a template literal in this file changes what a *fresh* install gets and
    /// nothing else: every device that has already launched keeps the wording it was seeded with
    /// for the life of the install, because generation reads the stored row and not the literal.
    /// #1329 is the case that made it matter — three templates asked the model for a person's
    /// OFFICE, and on the 266 volumes that publish no list of persons nothing on the device can
    /// corroborate one — but the gap is general: before this, a shipped prompt was unreachable
    /// after first launch.
    ///
    /// ## Why it compares three fields and not one
    /// `promptText`, `responseFormat` AND `schema`. The office ask lived in the structured field
    /// DESCRIPTIONS as much as in the prose, and those descriptions are stored on the row — twice,
    /// since `schema` mirrors the schema inside `responseFormat` — and reach the model verbatim
    /// through `AppleIntelligenceProvider`. A pass comparing only `promptText` would have shipped
    /// the reworded prose beside a schema still asking for an official capacity.
    ///
    /// ## The join key is the NAME, and three passes now share it
    /// `PromptTemplate.id` is never persisted — `SummarizationPrompt.init` mints its own — so the
    /// name is the only key on the row, exactly as it already is for `seed`'s skip and for
    /// `collapseDuplicates`'s grouping. The names are `String(localized:)`, so all three would
    /// break together if a translation for `prompt.template.*.name` were ever shipped: this pass
    /// would silently stop matching while `seed` minted a second row under the new name. The app
    /// ships no localization today — no `.lproj`, no string catalog, `knownRegions = (Base, en)` —
    /// so every one of those keys resolves to its `defaultValue` on every device.
    ///
    /// ## Why it stamps `lastModified` by hand
    /// `SummarizationPrompt`'s five `didSet { lastModified = .now }` observers never fire: the
    /// `@Model` macro rewrites a stored property into a computed pair and discards the observer,
    /// which `ModelModificationStamper` documents and `ModelLastModifiedTests` measures. The type
    /// is also not a `LastModifiedStamping` conformer, and `seed` works on its own `ModelContext`
    /// rather than the one the stamper observes, so nothing else would move it. Left frozen at
    /// creation, a device still running the old wording wins the CloudKit merge and puts the stale
    /// text back — the fix would arrive and then quietly leave again. The stamp differs per device
    /// for the same logical change, which is harmless precisely because both sides converge on the
    /// same text.
    ///
    /// Only `isStandard == true` rows. A reader's own prompt may legitimately share a name with a
    /// standard one, and it is theirs.
    ///
    /// Labelled `context:` and saving its own work, for the reasons `collapseDuplicates` gives.
    ///
    /// - Parameter context: the context to refresh in.
    /// - Returns: how many standard prompts were rewritten.
    @MainActor
    @discardableResult
    static func refreshStandardPrompts(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<SummarizationPrompt>(
            predicate: #Predicate { $0.isStandard == true }
        )
        guard let standard = try? context.fetch(descriptor) else { return 0 }

        var templatesByName: [String: PromptTemplate] = [:]
        for template in standardTemplates { templatesByName[template.name] = template }

        var refreshed = 0
        for prompt in standard {
            guard let template = templatesByName[prompt.name] else { continue }
            guard prompt.promptText != template.promptText
                    || prompt.responseFormat != template.responseFormat
                    || prompt.schema != template.schema
            else { continue }

            prompt.promptText = template.promptText
            prompt.responseFormat = template.responseFormat
            prompt.schema = template.schema
            prompt.lastModified = .now
            refreshed += 1
        }
        guard refreshed > 0 else { return 0 }

        do {
            try context.save()
        } catch {
            // A failed save leaves the old wording in place, which is the right failure: the next
            // import's debounce, or the next cold boot, retries.
            print("[SummarizationPromptSeeder] Refresh save failed: \(error)")
            return 0
        }
        // Deliberately NOT `#if DEBUG`, for the reason the collapse gives: this write propagates
        // to every device through CloudKit.
        print("[SummarizationPromptSeeder] Refreshed \(refreshed) standard prompt(s)")
        return refreshed
    }

    // MARK: - Template Definitions

    private static let generalTemplate = PromptTemplate(
        id: UUID(uuidString: "AA200000-0000-0000-0000-000000000001")!,
        name: String(localized: "prompt.template.standard.name",
                     defaultValue: "Standard Summary"),
        promptText: """
            Summarize the following document in two to four sentences. Identify who is \
            involved, naming them as the document names them, what the document concerns, \
            and what its principal content or outcome is. Do not supply a name, title, or \
            office the document does not state, and do not speculate beyond what is stated.

            {{DOCUMENT}}
            """,
        fields: []
    )

    private static let meetingRecordTemplate = PromptTemplate(
        id: UUID(uuidString: "AA200000-0000-0000-0000-000000000002")!,
        name: String(localized: "prompt.template.meeting.name",
                     defaultValue: "Meeting Record"),
        promptText: """
            Summarize the following meeting record. Identify the key participants and \
            the roles the document gives them, the main topics discussed, any agreements \
            reached, and any significant points of disagreement or unresolved tension. \
            Name people and roles only as the document states them; do not supply a title \
            or office it does not give.

            {{DOCUMENT}}
            """,
        fields: [
            .init(name: "KeyParticipants",
                  description: "Principal speakers, with the official capacity the document states for them"),
            .init(name: "Topics",
                  description: "Main subjects discussed"),
            .init(name: "Agreements",
                  description: "Points of consensus or decisions reached"),
            .init(name: "Disagreements",
                  description: "Notable points of divergence or unresolved issues"),
        ]
    )

    private static let policyDecisionTemplate = PromptTemplate(
        id: UUID(uuidString: "AA200000-0000-0000-0000-000000000003")!,
        name: String(localized: "prompt.template.policy.name",
                     defaultValue: "Policy Decision"),
        promptText: """
            Summarize the following policy document. If a decision is recorded, identify \
            what was decided, the principal alternatives considered, and the key \
            justifications cited. If no decision is recorded, describe the action or \
            decision being sought, the alternatives presented, and any recommendations \
            offered by the document's author.

            {{DOCUMENT}}
            """,
        fields: [
            .init(name: "Decision",
                  description: "The decision made, or if none is recorded, the action or decision being sought"),
            .init(name: "Alternatives",
                  description: "Major alternatives presented or considered"),
            .init(name: "Rationale",
                  description: "Key justifications cited, or recommendations offered by the document's author"),
        ]
    )

    private static let analyticalReportTemplate = PromptTemplate(
        id: UUID(uuidString: "AA200000-0000-0000-0000-000000000004")!,
        name: String(localized: "prompt.template.analytical.name",
                     defaultValue: "Analytical Report"),
        promptText: """
            Summarize the following analytical document. Identify the subject being \
            assessed or reported on, the principal findings or conclusions, any \
            significant uncertainties or limitations noted, and the assessed implications \
            for U.S. policy or interests.

            {{DOCUMENT}}
            """,
        fields: [
            .init(name: "Subject",
                  description: "The topic, country, situation, or development being assessed or reported"),
            .init(name: "Findings",
                  description: "Principal conclusions, assessments, or reporting"),
            .init(name: "KeyUncertainties",
                  description: "Significant gaps, caveats, or limitations noted"),
            .init(name: "PolicyImplications",
                  description: "Assessed implications for U.S. policy or interests"),
        ]
    )

    private static let diplomaticExchangeTemplate = PromptTemplate(
        id: UUID(uuidString: "AA200000-0000-0000-0000-000000000005")!,
        name: String(localized: "prompt.template.diplomatic.name",
                     defaultValue: "Diplomatic Exchange"),
        promptText: """
            Summarize the following diplomatic document. Identify the parties \
            communicating as the document names them, the subject of the exchange, the \
            key substance conveyed, and the diplomatic register or tone. Do not supply a \
            name, title, government, or office the document does not state.

            {{DOCUMENT}}
            """,
        fields: [
            .init(name: "Parties",
                  description: "Sending and receiving parties, with the governments and positions the document states"),
            .init(name: "Subject",
                  description: "The matter being communicated"),
            .init(name: "Substance",
                  description: "Key points, requests, positions, or information conveyed"),
            .init(name: "Register",
                  description: "The diplomatic tone (e.g., urgent, routine, conciliatory, confrontational)"),
        ]
    )

    private static let crisisEventTemplate = PromptTemplate(
        id: UUID(uuidString: "AA200000-0000-0000-0000-000000000006")!,
        name: String(localized: "prompt.template.crisis.name",
                     defaultValue: "Crisis Event"),
        promptText: """
            Summarize the following document in the context of a developing crisis or \
            emergency situation. Describe the situation as presented, the status at the \
            time of the document, actions taken or under consideration, and the stakes \
            or urgency conveyed.

            {{DOCUMENT}}
            """,
        fields: [
            .init(name: "Situation",
                  description: "Description of the event or developing crisis"),
            .init(name: "Status",
                  description: "State of affairs at the time of the document"),
            .init(name: "Response",
                  description: "Actions taken or under consideration"),
            .init(name: "Stakes",
                  description: "Characterization of urgency and potential consequences"),
        ]
    )

    private static let individualRoleTraceTemplate = PromptTemplate(
        id: UUID(uuidString: "AA200000-0000-0000-0000-000000000007")!,
        name: String(localized: "prompt.template.individual.name",
                     defaultValue: "Individual Role Trace"),
        promptText: """
            Summarize the role of [name of individual] in the following document. \
            Describe the capacity in which the document presents them, what they said or \
            did, the positions they expressed or represented, and why their involvement \
            is significant. Give the capacity only as the document states it; if the \
            document states none, say so rather than supplying one.

            {{DOCUMENT}}
            """,
        fields: [
            .init(name: "Role",
                  description: "The role or official capacity this document states for the individual, or that it states none"),
            .init(name: "Actions",
                  description: "What they said, proposed, decided, or did"),
            .init(name: "Positions",
                  description: "Views or positions they expressed or represented"),
            .init(name: "Significance",
                  description: "Why their involvement matters in this document's context"),
        ]
    )

    private static let relevanceAssessmentTemplate = PromptTemplate(
        id: UUID(uuidString: "AA200000-0000-0000-0000-000000000008")!,
        name: String(localized: "prompt.template.relevance.name",
                     defaultValue: "Relevance Assessment"),
        promptText: """
            Review the following document for its relevance to [describe your research \
            criteria here — e.g., the institutional history of the Department of State, \
            including the development of its organizational structure, diplomatic \
            practices, policymaking processes, and relationships with other government \
            agencies]. Provide a brief description of the document's subject, an \
            assessment of its relevance to your criteria, and the specific content from \
            the document that supports your assessment.

            {{DOCUMENT}}
            """,
        fields: [
            .init(name: "Subject",
                  description: "Brief description of what the document is about"),
            .init(name: "RelevanceAssessment",
                  description: "Whether and how the document is relevant to the stated criteria"),
            .init(name: "SupportingEvidence",
                  description: "Specific content from the document that informs the assessment"),
        ]
    )
}
