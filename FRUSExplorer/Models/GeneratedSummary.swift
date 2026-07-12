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
    /// "AI-generated". Defaults to `.aiGenerated`, so every existing summary is attributed as before.
    var authorship: SummaryAuthorship = SummaryAuthorship.aiGenerated {
        didSet { lastModified = .now }
    }

    /// `true` for a summary that exists solely as a collection entry's editable headnote draft
    /// (Composer redesign). Such summaries are excluded from the document's summary carousel and
    /// the headnote-source picker, so editing a headnote never pollutes the document's summaries.
    /// `false` for every ordinary summary. Defaults to `false`, so existing summaries are unaffected.
    var isHeadnoteDraft: Bool = false {
        didSet { lastModified = .now }
    }

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
        isHeadnoteDraft: Bool = false
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

