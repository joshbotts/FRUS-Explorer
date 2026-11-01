// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import FoundationModels
import OSLog

// MARK: - AppleIntelligenceProvider

/// Default `SummarizationProvider` backed by Apple Intelligence (on-device LLM).
///
/// ## Availability
/// `isAvailable` reflects `SystemLanguageModel.default.isAvailable` at call time.
/// Devices without Apple Intelligence hardware return `false`; the app hides all
/// summarization entry points in that case. No API key or network connection required.
///
/// ## Context window
/// The model states its window as `SystemLanguageModel.contextSize`, and it differs by device: 8,192
/// tokens on this project's M5 Mac under macOS 27.2 (variant "AFM 3 Core Advanced"), and the same in the
/// app on the iOS 27.0 simulator, which runs the Mac's model; 4,096 on every device before iOS and
/// macOS 27 (the SDK's back-deployed answer). A command-line tool spawned in that simulator read 0, and
/// still answered a prompt of 7,414 tokens. Apple's forum reply on thread 843063 puts the iPhone 17
/// Pro, 17 Pro Max and Air on the advanced model under iOS 27 and the iPhone 15 Pro and 16 on a 3B model
/// with 4K. `contextWindowTokenLimit` is three quarters of that window, read at each request, and never
/// below 3,072 or above 6,144 (``tokenLimit(forContextSize:)``): 6,144 on an 8K model, 3,072 on any
/// other. It bounds the prompt only. The window holds the prompt and the answer together, so the other
/// quarter is the answer's room, and an answer that runs past it throws
/// `LanguageModelError.contextSizeExceeded` once it is written.
///
/// Measured 2026-10-31 on the Mac, against 3,072: 22 long documents, 1870 to 1988, under the Standard
/// Summary and the Meeting Record, one run of each at each limit. 6,144 took 31% less time and made half
/// the model calls, and its summaries named as much of each document: of eight equal parts, a Meeting
/// Record kept 7.5 against 7.1, and a Standard Summary 1.9 for each hundred words against 1.8. 7,168 lost
/// one run when an answer ran past the window. `Planning/DEVELOPMENT-PLAN.md` has the measurement.
/// The service's estimate of a text's tokens is ``SummarizationService/estimateTokens(_:)``.
///
/// ## Structured output
/// A `.structured` prompt's answer is generated as plain text, its fields asked for as Markdown headings
/// in the session's instructions, and read back into the JSON object stored as
/// `GeneratedSummary.responseText`: a string per field, keyed by the field's name
/// (`StructuredSectionAnswer`, 2026-10-31). Until then it was guided generation over a
/// `DynamicGenerationSchema`, which the on-device model declined for most FRUS documents (38 of 270
/// in the measurement `StructuredSectionAnswer` records, against 108 of 108 as plain text).
///
/// ## Guardrails (#1765)
/// Every prompt runs on Apple's `permissiveContentTransformations` guardrails (``model``), the mode
/// Apple gives for transforming supplied text, summarizing included. Under the default guardrails the
/// Standard Summary of the Long Telegram (`frus1946v06/d475`) failed in 3 of 3 runs on a Mac under
/// macOS 27.2, at its third or fourth chunk of five; under the permissive ones it summarized in 3 of 3,
/// and fourteen other documents of the volume summarized under both (2026-10-31; the owner chose the
/// permissive mode that day for plain-text prompts). A structured prompt kept the default guardrails
/// while it was guided generation, since Apple's mode behaves as the default for any answer that is not
/// a `String`; as plain text it takes the permissive mode too, and the owner chose that the same day.
/// When the model still declines, ``summarize(request:prompt:)`` throws
/// `SummarizationError.contentRefused` in place of the framework's error, so every surface that prints
/// the failure reads a sentence a reader can act on.
///
/// Version history:
///   1.0 — Session 19: initial implementation
///   1.1 — #1765: plain-text prompts on the permissive guardrails; a guardrail stop or refusal is
///          thrown as `SummarizationError.contentRefused`
///   1.2 — 2026-10-31: a structured prompt is answered as plain text under headings on the permissive
///          guardrails and read back into its fields, where guided generation was declined
///   1.3 — 2026-10-31: `contextWindowTokenLimit` is three quarters of the model's stated window, from
///          3,072 to 6,144, where it was 3,072 on every device; the window is logged once a launch
actor AppleIntelligenceProvider: SummarizationProvider {

    // MARK: - Shared Instance

    static let shared = AppleIntelligenceProvider()
    private init() {}

    /// The log the provider writes the model's window to, once a launch.
    private static let log = Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "Summarization")

    /// Whether this launch has logged the model's window.
    private var hasLoggedContextSize = false

    // MARK: - SummarizationProvider

    /// The prompt budget for one request: three quarters of the model's stated window, from 3,072 to
    /// 6,144 (see header comment). The first read of a launch logs the window it was taken from.
    var contextWindowTokenLimit: Int {
        let contextSize = Self.model.contextSize
        let limit = Self.tokenLimit(forContextSize: contextSize)
        if !hasLoggedContextSize {
            hasLoggedContextSize = true
            Self.logContextSize(contextSize, limit: limit)
        }
        return limit
    }

    /// The least prompt budget: the one the app used on every device until 2026-10-31, kept for a
    /// 4,096-token window and for a window the model states as 0 (as one process in the iOS 27.0
    /// simulator read it) or anything under 4,096.
    static let minimumTokenLimit = 3_072

    /// The greatest prompt budget: three quarters of 8,192, the largest window measured. A larger window
    /// is held to it until it is measured too.
    static let maximumTokenLimit = 6_144

    /// The prompt budget for a model whose window is `contextSize` tokens: three quarters of it, from
    /// ``minimumTokenLimit`` to ``maximumTokenLimit``.
    static func tokenLimit(forContextSize contextSize: Int) -> Int {
        min(maximumTokenLimit, max(minimumTokenLimit, contextSize / 4 * 3))
    }

    /// Logs the model's window, its variant where the system names one, and the budget taken from it,
    /// so a device's figure can be read from its log.
    private static func logContextSize(_ contextSize: Int, limit: Int) {
        var variant = "unnamed"
        if #available(iOS 27.0, macOS 27.0, *) {
            variant = model.variant.displayName
        }
        log.notice("On-device model: \(variant, privacy: .public), context \(contextSize, privacy: .public) tokens, prompt budget \(limit, privacy: .public)")
    }

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
            let structured: Bool
            if case .structured = prompt.responseFormat { structured = true } else { structured = false }
            throw Self.translatingRefusal(error, structured: structured)
        }

        return SummarizationResult(
            text: text,
            responseFormat: prompt.responseFormat,
            wasChunked: false   // SummarizationService sets the final wasChunked flag
        )
    }

    // MARK: - Guardrails

    /// The on-device model every prompt runs on, under Apple's `permissiveContentTransformations`
    /// guardrails (#1765).
    ///
    /// It is Apple's mode for turning supplied text into text, such as summarizing an article: a request
    /// that generates a `String` does not throw a guardrail violation in it, though the model may still
    /// decline by writing a refusal as its answer. Every prompt generates a `String` since 2026-10-31,
    /// a structured one included (``structuredJSON(fromAnswer:schema:)``). Under the default
    /// guardrails the same plain-text answers under headings summarized 52 of 54 documents; the two
    /// stops were the classifier's, one of them on the Long Telegram's fourth chunk.
    static var model: SystemLanguageModel {
        SystemLanguageModel(guardrails: .permissiveContentTransformations)
    }

    // MARK: - Structured answers

    /// The JSON a structured summary stores, read from the model's answer under `schema`'s headings
    /// (`StructuredSectionAnswer`).
    ///
    /// Throws `SummarizationError.contentRefused(structured: true)` when a field's heading is missing:
    /// a refusal written as the answer has none, and storing it would put the refusal in the summary.
    /// None of the 441 answers of the two full runs of 2026-10-31 (297 on the permissive guardrails,
    /// 144 on the default) lacked a heading.
    static func structuredJSON(fromAnswer answer: String, schema: StructuredSummarySchema) throws -> String {
        guard let values = StructuredSectionAnswer.values(in: answer, schema: schema) else {
            throw SummarizationError.contentRefused(structured: true)
        }
        return StructuredSectionAnswer.jsonString(values, schema: schema)
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
        let session = LanguageModelSession(model: Self.model)
        let response = try await session.respond(to: promptText)
        return response.content
    }

    /// The prompt's own text as the request, its fields as headings in the session's instructions.
    private func structuredResponse(
        promptText: String,
        schema: StructuredSummarySchema
    ) async throws -> String {
        let session = LanguageModelSession(model: Self.model,
                                           instructions: StructuredSectionAnswer.instructions(for: schema))
        let response = try await session.respond(to: promptText)
        return try Self.structuredJSON(fromAnswer: response.content, schema: schema)
    }
}
