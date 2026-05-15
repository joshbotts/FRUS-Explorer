// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - StructuredSummarySchema

/// Defines the field structure for a structured AI summarization prompt.
///
/// Used with `ResponseFormat.structured` to instruct the AI model to return
/// a schema-conformant JSON object rather than free-form prose. Each `Field`
/// corresponds to a top-level key in the expected JSON response.
///
/// Example: a biographical summary schema might have fields "Background",
/// "Key Positions", "Notable Actions in Document".
///
/// Version history:
///   1.0 — Session 04: initial implementation
public struct StructuredSummarySchema: Codable, Sendable, Equatable {

    /// A single named field in the structured summary schema.
    public struct Field: Codable, Sendable, Equatable {
        /// The field name used as the JSON key. e.g. `"Background"`.
        public let name: String
        /// Human-readable description of what the AI should put in this field.
        public let description: String

        public init(name: String, description: String) {
            self.name = name
            self.description = description
        }
    }

    /// Ordered list of fields the AI model should populate.
    public let fields: [Field]

    public init(fields: [Field]) {
        self.fields = fields
    }
}

// MARK: - ResponseFormat

/// Controls the output format of an AI summarization request.
///
/// `general` requests free-form prose. `structured` provides a schema that the
/// AI model uses with `ResponseFormat` (JSON mode) to produce a structured object
/// whose keys match `StructuredSummarySchema.fields`.
///
/// Stored in `GeneratedSummary` and `SummarizationPrompt` as a `Codable` value.
/// SwiftData serializes this to a `Data` blob for CloudKit sync.
///
/// Version history:
///   1.0 — Session 04: initial implementation
public enum ResponseFormat: Codable, Sendable, Equatable {
    /// Free-form prose summary. No output schema enforced.
    case general
    /// Schema-constrained JSON output. The AI model receives the schema and
    /// is instructed to populate each named field.
    case structured(schema: StructuredSummarySchema)
}
