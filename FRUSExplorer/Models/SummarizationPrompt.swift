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
