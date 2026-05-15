// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import FoundationModels

// MARK: - AppleIntelligenceProvider

/// Default `SummarizationProvider` backed by Apple Intelligence (on-device LLM).
///
/// ## Availability
/// `isAvailable` reflects `SystemLanguageModel.default.isAvailable` at call time.
/// Devices without Apple Intelligence hardware return `false`; the app hides all
/// summarization entry points in that case. No API key or network connection required.
///
/// ## Context window
/// Apple does not publish the Apple Intelligence context window size. `contextWindowTokenLimit`
/// is set to 3 072 — a conservative budget that reserves roughly 1 024 tokens for the
/// system prompt and response overhead, based on a 4 096-token working assumption.
/// Token estimation throughout the service layer uses a 4-characters-per-token heuristic
/// (~250 words per 1 000 tokens for English prose); underestimation causes unnecessary
/// chunking rather than exceeded-context errors.
///
/// ## Structured output
/// For `.structured` prompts, a `GenerationSchema` is built at runtime from the
/// prompt's `StructuredSummarySchema.fields` using `DynamicGenerationSchema`. Each
/// field becomes a `String`-typed property in the root object schema. The response
/// is a `GeneratedContent` value; its `jsonString` is stored as `GeneratedSummary.responseText`.
///
/// Version history:
///   1.0 — Session 19: initial implementation
actor AppleIntelligenceProvider: SummarizationProvider {

    // MARK: - Shared Instance

    static let shared = AppleIntelligenceProvider()
    private init() {}

    // MARK: - SummarizationProvider

    /// Conservative token budget for document content per request (see header comment).
    let contextWindowTokenLimit: Int = 3_072

    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func summarize(
        request: SummarizationRequest,
        prompt: SummarizationPromptSnapshot
    ) async throws -> SummarizationResult {
        guard isAvailable else { throw SummarizationError.providerUnavailable }

        let body = request.chunks.joined(separator: "\n\n")
        let promptText = prompt.promptText
            .replacingOccurrences(of: "{{DOCUMENT}}", with: body)

        let text: String
        switch prompt.responseFormat {
        case .general:
            text = try await generalResponse(promptText: promptText)
        case .structured(let schema):
            text = try await structuredResponse(promptText: promptText, schema: schema)
        }

        return SummarizationResult(
            text: text,
            responseFormat: prompt.responseFormat,
            wasChunked: false   // SummarizationService sets the final wasChunked flag
        )
    }

    // MARK: - Private

    private func generalResponse(promptText: String) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond(to: promptText)
        return response.content
    }

    private func structuredResponse(
        promptText: String,
        schema: StructuredSummarySchema
    ) async throws -> String {
        let genSchema = try buildGenerationSchema(from: schema)
        let session = LanguageModelSession()
        let response = try await session.respond(to: promptText, schema: genSchema)
        return response.content.jsonString
    }

    /// Builds a `GenerationSchema` from a `StructuredSummarySchema` at runtime.
    ///
    /// Each schema field becomes a `String`-typed property in the root object.
    /// The `DynamicGenerationSchema(type: String.self)` overload creates a schema
    /// representing a primitive string value, matching `String`'s `Generable` conformance.
    private func buildGenerationSchema(
        from schema: StructuredSummarySchema
    ) throws -> GenerationSchema {
        let properties = schema.fields.map { field in
            DynamicGenerationSchema.Property(
                name: field.name,
                description: field.description,
                schema: DynamicGenerationSchema(type: String.self)
            )
        }
        let root = DynamicGenerationSchema(
            name: "StructuredSummary",
            description: "Structured summary with named fields",
            properties: properties
        )
        return try GenerationSchema(root: root, dependencies: [])
    }
}
