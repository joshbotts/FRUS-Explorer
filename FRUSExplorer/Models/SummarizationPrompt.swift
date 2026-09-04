// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - SummarizationPrompt

/// A reusable AI summarization prompt template.
///
/// Standard prompts (`isStandard == true`) ship with the app and are not editable.
/// User-created prompts (`isStandard == false`) are created in the Settings → Prompts
/// panel and can be edited or deleted.
///
/// ## Response Format
/// `responseFormat` and `schema` together control how the AI output is structured:
/// - `.general`: free-form prose. `schema` is nil.
/// - `.structured(schema:)`: JSON-mode output. The `schema` field mirrors the schema
///   embedded in the `responseFormat` associated value for direct access without
///   decoding the enum.
///
/// ## `promptText`
/// Plain text with optional `{{DOCUMENT}}` placeholder substituted at generation
/// time with the document body. Additional template variables are defined in Session 20.
///
/// Version history:
///   1.0 — Session 04: initial implementation
@Model final class SummarizationPrompt {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Content

    var name: String = "" {
        didSet { lastModified = .now }
    }

    /// The prompt template text. May contain `{{DOCUMENT}}` for document substitution.
    var promptText: String = "" {
        didSet { lastModified = .now }
    }

    /// Controls whether the AI returns free-form prose or a structured JSON object.
    var responseFormat: ResponseFormat = ResponseFormat.general {
        didSet { lastModified = .now }
    }

    /// `true` for prompts shipped with the app; `false` for user-created prompts.
    /// Standard prompts are read-only in the UI.
    var isStandard: Bool = false {
        didSet { lastModified = .now }
    }

    /// The field schema for structured prompts. Mirrors the schema in `responseFormat`
    /// for direct access without unwrapping the enum. `nil` for `.general` prompts.
    var schema: StructuredSummarySchema? {
        didSet { lastModified = .now }
    }

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var lastModified: Date?

    // MARK: - Initializer

    init(
        name: String,
        promptText: String,
        responseFormat: ResponseFormat = .general,
        isStandard: Bool = false,
        schema: StructuredSummarySchema? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.promptText = promptText
        self.responseFormat = responseFormat
        self.isStandard = isStandard
        self.schema = schema
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] SummarizationPrompt created: \(id) '\(name)' standard=\(isStandard)")
        #endif
    }
}

// MARK: - Which prompt a regeneration runs (R-5 P3b-6)

extension SummarizationPrompt {

    /// What resolving a summary's prompt found — the OUTCOME, not just a prompt.
    ///
    /// Three outcomes need three sentences, and the whole defect this replaces was a caller that
    /// could not tell them apart: macOS's Regenerate fetched every prompt ordered by `createdAt`
    /// and took the first, so it could not distinguish "this summary's own prompt" from "some other
    /// prompt that happens to be oldest", and told the reader nothing either way.
    /// Not `Sendable`: it carries live `@Model` references, which are MainActor-bound. Every
    /// caller resolves on the main actor and converts to a `SummarizationPromptSnapshot` before
    /// crossing into `SummarizationService`, which is the boundary that already exists.
    enum Resolution {
        /// The summary's own prompt, still on this device. Regenerating reproduces it faithfully.
        case requested(SummarizationPrompt)
        /// The requested prompt is gone — a reader deleted it, and nothing repoints a summary when
        /// they do — so a regeneration would substitute this standard one. The caller must SAY so
        /// before running: a substitution the reader is not warned about produces a summary in a
        /// voice they did not choose.
        case standardFallback(SummarizationPrompt)
        /// No prompt at all. Reachable: Erase Everything deletes every `SummarizationPrompt` and
        /// the seeder runs only at launch, so the store stays empty for the rest of that session —
        /// and the deletion syncs to a device that already seeded.
        case unavailable
    }

    /// Resolves the prompt a regeneration should use.
    ///
    /// - Parameters:
    ///   - preferredId: the `promptId` of the summary being regenerated, or `nil` when there is no
    ///     summary yet and any standard prompt will do.
    ///   - context: the model context to read from.
    ///
    /// **The standard fallback sorts IN MEMORY, coercing a nil `createdAt` to `.distantFuture`.**
    /// `createdAt` is optional, and a raw `SortDescriptor(\.createdAt)` puts NULL FIRST ascending —
    /// so a legacy or CloudKit-synced row with no date would become "the oldest prompt" and win.
    /// `SummarizationPromptSeeder.stableKeeper` already guards exactly that case, which is the
    /// evidence such rows are real rather than hypothetical.
    ///
    /// The fallback also filters on `isStandard`, which the code this replaces did not: its fetch
    /// had no such predicate, so it could return a user's own prompt and call it the default.
    static func resolve(preferredId: UUID?, in context: ModelContext) -> Resolution {
        if let id = preferredId,
           let prompt = (try? context.fetch(
               FetchDescriptor<SummarizationPrompt>(predicate: #Predicate { $0.id == id })))?.first {
            return .requested(prompt)
        }
        let all = (try? context.fetch(FetchDescriptor<SummarizationPrompt>())) ?? []
        // Standards first — a substitute should be one the app shipped, not one the reader wrote —
        // but NOT standards only. A reader whose store is empty is told to add a prompt in
        // Settings, and a prompt they add is `isStandard == false`: a standards-only fallback would
        // still report "no prompt is available" after they had followed the instruction exactly.
        let pool = all.contains(where: \.isStandard) ? all.filter(\.isStandard) : all
        guard let oldest = pool.min(by: Self.olderForFallback) else { return .unavailable }
        return .standardFallback(oldest)
    }
    /// A TOTAL order for the fallback, so the prompt named and the prompt run cannot differ.
    ///
    /// `min(by:)` is not documented as stable, so a comparator that returns false in both
    /// directions for two rows — two standards seeded in the same tick, which is exactly how the
    /// seeder inserts them — leaves the winner up to the fetch order. The id breaks that tie the
    /// way `GeneratedSummary.ranksAbove` breaks its own.
    fileprivate static func olderForFallback(_ a: SummarizationPrompt, _ b: SummarizationPrompt) -> Bool {
        let da = a.createdAt ?? .distantFuture, db = b.createdAt ?? .distantFuture
        if da != db { return da < db }
        return a.id.uuidString < b.id.uuidString
    }
}

extension SummarizationPrompt.Resolution {
    /// The prompt to run, or `nil` when there is none to run.
    var prompt: SummarizationPrompt? {
        switch self {
        case .requested(let p), .standardFallback(let p): return p
        case .unavailable: return nil
        }
    }

    /// The name to print BESIDE a summary as its provenance, or `nil` when none may be printed.
    ///
    /// Only ``SummarizationPrompt/Resolution/requested(_:)`` yields one. A substitute must never be
    /// named here: the label describes the prompt that MADE this summary, and naming the prompt
    /// that would remake it would attribute a summary to a prompt that never wrote a word of it.
    var provenanceName: String? {
        if case .requested(let p) = self { return p.name }
        return nil
    }
}
