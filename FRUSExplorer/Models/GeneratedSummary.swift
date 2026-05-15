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
/// Version history:
///   1.0 — Session 04: initial implementation
///   1.1 — Session 32: added `@unchecked Sendable` conformance; the model is only ever
///          mutated on the `@MainActor` context that owns its `ModelContext`
@Model final class GeneratedSummary {

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
        projectId: UUID? = nil
    ) {
        self.id = UUID()
        self.documentId = documentId
        self.volumeId = volumeId
        self.promptId = promptId
        self.responseText = responseText
        self.responseFormat = responseFormat
        self.wasChunked = wasChunked
        self.projectId = projectId
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] GeneratedSummary created: \(id) for \(volumeId)/\(documentId)")
        #endif
    }
}

extension GeneratedSummary: @unchecked Sendable {}
