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
/// ## Log prefix
/// `[SummarizationPromptSeeder]`
///
/// Version history:
///   1.0 — Session 20: initial implementation
///   1.1 — Session 75: per-name idempotency check + deduplication pass to fix
///          CloudKit sync race that produced duplicate standard prompts when both
///          Mac and iOS seeded before the first batch had synced.
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

        // Deduplication pass: group standard prompts by name; for each group with
        // more than one entry, delete all but the oldest (smallest createdAt).
        let allStandard = (try? context.fetch(descriptor)) ?? existing
        var byName: [String: [SummarizationPrompt]] = [:]
        for prompt in allStandard {
            byName[prompt.name, default: []].append(prompt)
        }
        var deleteCount = 0
        for (_, group) in byName where group.count > 1 {
            // Sort ascending by createdAt (nil sorts last so oldest non-nil wins).
            let sorted = group.sorted {
                ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture)
            }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                deleteCount += 1
            }
        }

        guard insertCount > 0 || deleteCount > 0 else {
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
            if deleteCount > 0 {
                print("[SummarizationPromptSeeder] Removed \(deleteCount) duplicate standard prompt(s)")
            }
            #endif
        } catch {
            #if DEBUG
            print("[SummarizationPromptSeeder] Save failed: \(error)")
            #endif
        }
    }

    // MARK: - Template Definitions

    private static let generalTemplate = PromptTemplate(
        id: UUID(uuidString: "AA200000-0000-0000-0000-000000000001")!,
        name: String(localized: "prompt.template.standard.name",
                     defaultValue: "Standard Summary"),
        promptText: """
            Summarize the following document in two to four sentences. Identify who is \
            involved, what the document concerns, and what its principal content or \
            outcome is. Do not speculate beyond what is stated.

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
            their roles, the main topics discussed, any agreements reached, and any \
            significant points of disagreement or unresolved tension.

            {{DOCUMENT}}
            """,
        fields: [
            .init(name: "KeyParticipants",
                  description: "Principal speakers and their official capacity"),
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
            communicating, the subject of the exchange, the key substance conveyed, \
            and the diplomatic register or tone.

            {{DOCUMENT}}
            """,
        fields: [
            .init(name: "Parties",
                  description: "Sending and receiving parties, including their governments and positions"),
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
            Describe the capacity in which they appear, what they said or did, the \
            positions they expressed or represented, and why their involvement is \
            significant.

            {{DOCUMENT}}
            """,
        fields: [
            .init(name: "Role",
                  description: "The individual's role or official capacity in this document"),
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
