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
/// ## Guardrails (#1765)
/// A plain-text prompt runs on Apple's `permissiveContentTransformations` guardrails, the mode Apple
/// gives for transforming supplied text, summarizing included; a structured prompt keeps the default
/// ones, which is all Apple's mode offers it (``GuardrailMode``). Under the default guardrails the
/// Standard Summary of the Long Telegram (`frus1946v06/d475`) failed in 3 of 3 runs on a Mac under
/// macOS 27.2, at its third or fourth chunk of five; under the permissive ones it summarized in 3 of 3,
/// and fourteen other documents of the volume summarized under both (2026-10-31; the owner chose the
/// permissive mode that day). When the model still declines, ``summarize(request:prompt:)`` throws
/// `SummarizationError.contentRefused` in place of the framework's error, so every surface that prints
/// the failure reads a sentence a reader can act on.
///
/// Version history:
///   1.0 — Session 19: initial implementation
///   1.1 — #1765: plain-text prompts on the permissive guardrails; a guardrail stop or refusal is
///          thrown as `SummarizationError.contentRefused`
actor AppleIntelligenceProvider: SummarizationProvider {

    // MARK: - Shared Instance

    static let shared = AppleIntelligenceProvider()
    private init() {}

    // MARK: - SummarizationProvider

    /// Conservative token budget for document content per request (see header comment).
    let contextWindowTokenLimit: Int = 3_072

    /// `nonisolated` so DocumentView can read this from the `@MainActor` without an
    /// `await`. `SystemLanguageModel.default.isAvailable` is a safe synchronous read;
    /// no actor state is mutated here.
    nonisolated var isAvailable: Bool {
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
        do {
            switch prompt.responseFormat {
            case .general:
                text = try await generalResponse(promptText: promptText)
            case .structured(let schema):
                text = try await structuredResponse(promptText: promptText, schema: schema)
            }
        } catch {
            let structured = Self.guardrailMode(for: prompt.responseFormat) == .standard
            throw Self.translatingRefusal(error, structured: structured)
        }

        return SummarizationResult(
            text: text,
            responseFormat: prompt.responseFormat,
            wasChunked: false   // SummarizationService sets the final wasChunked flag
        )
    }

    // MARK: - Guardrails

    /// Which of Apple's guardrail modes a prompt's session runs under (#1765).
    ///
    /// Apple's `permissiveContentTransformations` is the mode for turning supplied text into text, such
    /// as summarizing an article: a request that generates a `String` does not throw a guardrail
    /// violation in it, though the model may still decline by writing a refusal as its answer. A
    /// request that generates anything else, guided generation included, *behaves the same way as
    /// default mode* (Apple's documentation of the mode), so a structured prompt gains nothing from it
    /// and keeps ``standard``, saying so rather than passing a setting that does nothing.
    enum GuardrailMode: Equatable {
        /// Apple's `permissiveContentTransformations`: plain-text prompts.
        case permissiveContentTransformations
        /// Apple's `default`: structured prompts.
        case standard

        /// The on-device model under this mode's guardrails.
        var model: SystemLanguageModel {
            switch self {
            case .permissiveContentTransformations:
                SystemLanguageModel(guardrails: .permissiveContentTransformations)
            case .standard:
                SystemLanguageModel.default
            }
        }
    }

    /// The guardrail mode a prompt of `format` runs under: permissive for plain text, the default for a
    /// structured answer (``GuardrailMode``).
    static func guardrailMode(for format: ResponseFormat) -> GuardrailMode {
        switch format {
        case .general: .permissiveContentTransformations
        case .structured: .standard
        }
    }

    // MARK: - Refusals

    /// `error` as `SummarizationError.contentRefused` when it is the model's guardrails stopping the
    /// request or the model declining to answer, and `error` unchanged otherwise (#1765).
    ///
    /// Both error families are read: an app built with the iOS and macOS 27 SDKs is thrown the new
    /// `LanguageModelError` on those systems (measured on macOS 27.2: a guardrail stop arrived as
    /// `LanguageModelError.guardrailViolation`, which `GenerationError` does not match) and the
    /// deprecated `LanguageModelSession.GenerationError` under iOS and macOS 26. A refusal's own
    /// explanation is not asked for (`SummarizationError.contentRefused`).
    static func translatingRefusal(_ error: any Error, structured: Bool) -> any Error {
        if #available(iOS 27.0, macOS 27.0, *), let modelError = error as? LanguageModelError {
            switch modelError {
            case .guardrailViolation, .refusal:
                return SummarizationError.contentRefused(structured: structured)
            default:
                return error
            }
        }
        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .guardrailViolation, .refusal:
                return SummarizationError.contentRefused(structured: structured)
            default:
                return error
            }
        }
        return error
    }

    // MARK: - Private

    private func generalResponse(promptText: String) async throws -> String {
        let session = LanguageModelSession(model: Self.guardrailMode(for: .general).model)
        let response = try await session.respond(to: promptText)
        return response.content
    }

    private func structuredResponse(
        promptText: String,
        schema: StructuredSummarySchema
    ) async throws -> String {
        let genSchema = try buildGenerationSchema(from: schema)
        let session = LanguageModelSession(model: Self.guardrailMode(for: .structured(schema: schema)).model)
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
