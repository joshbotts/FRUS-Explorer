// SummarisationService.swift
// Wraps the Apple Foundation Models framework to produce on-device summaries
// of FRUS documents, shaped by a user-chosen SummaryPromptProfile.

import Foundation
import FoundationModels

// MARK: - SummarisationService

/// Generates on-device summaries using `LanguageModelSession`.
/// A new session is created per request so the context window stays small.
actor SummarisationService {

    // MARK: - Core system instructions (profile-invariant)
    //
    // These instructions establish the model's role and impose formatting
    // discipline.  The profile-specific emphasis is injected into the user
    // prompt rather than here, so the system instructions remain concise and
    // do not grow with profile complexity.

    private static let baseInstructions = """
    You are a scholarly research assistant specialising in 20th-century American \
    diplomatic history. You produce concise, accurate summaries of documents from \
    the Foreign Relations of the United States (FRUS) series published by the \
    U.S. Office of the Historian.

    Core rules that ALWAYS apply, regardless of other instructions:
    • Write entirely in your own words — do not reproduce verbatim passages.
    • Use formal academic prose. No bullet lists, no headers, no markdown.
    • If text is too short to support the requested format, write a single \
      short paragraph and stop.
    • Never invent facts not present in the source text.
    """

    // MARK: - Public API

    /// Summarise `text` using `profile` to shape emphasis and output format.
    /// Falls back to `SummaryPromptProfile.defaultProfile` when `profile` is nil.
    func summarise(
        text: String,
        title: String,
        profile: SummaryPromptProfile? = nil
    ) async -> SummaryState {

        guard await SystemLanguageModel.default.isAvailable else {
            return .ready("Summary requires Apple Intelligence. Enable it in System Settings → Apple Intelligence & Siri.")
        }

        let resolvedProfile = profile ?? SummaryPromptProfile.defaultProfile
        let sample = buildSample(from: text)
        let userPrompt = buildPrompt(
            sample: sample.text,
            truncated: sample.truncated,
            title: title,
            profile: resolvedProfile
        )
        let systemInstructions = buildSystemInstructions(for: resolvedProfile)

        do {
            let session = LanguageModelSession(instructions: systemInstructions)
            let response = try await session.respond(to: userPrompt)
            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? .ready("Summary unavailable.") : .ready(content)
        } catch let error as LanguageModelSession.GenerationError {
            return .failed("Generation error: \(error.localizedDescription)")
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - System instructions

    private func buildSystemInstructions(for profile: SummaryPromptProfile) -> String {
        // The base instructions establish role + anti-hallucination + anti-verbatim rules.
        // The profile's emphasis instruction is appended so the model treats it as
        // a standing directive rather than a one-off request.
        var instructions = Self.baseInstructions
        if !profile.emphasisInstruction.trimmingCharacters(in: .whitespaces).isEmpty {
            instructions += "\n\nResearch focus for this session:\n\(profile.emphasisInstruction)"
        }
        return instructions
    }

    // MARK: - User prompt construction

    private func buildPrompt(
        sample: String,
        truncated: Bool,
        title: String,
        profile: SummaryPromptProfile
    ) -> String {

        let truncationNote = truncated
            ? "\n[The above is a representative excerpt — opening and closing passages. Do not reproduce it — synthesise from the whole.]"
            : ""

        // Build the output format directive from the profile
        let formatDirective = outputFormatDirective(for: profile)

        return """
        \(formatDirective)

        Document title: \(title.isEmpty ? "(untitled)" : title)

        Source text:
        \(sample)\(truncationNote)

        REMINDER: Write entirely in your own words. Do not copy phrases from the source.
        """
    }

    private func outputFormatDirective(for profile: SummaryPromptProfile) -> String {
        switch profile.outputFormat {
        case .threeSentence:
            return """
            Write a summary of the FRUS document below in EXACTLY three sentences:
            • Sentence 1 — document type, date, and principal parties or countries.
            • Sentence 2 — the main subject, proposal, or decision.
            • Sentence 3 — \(profile.emphasisInstruction.isEmpty ? "historical significance or outcome" : "the aspect highlighted by the research focus below").
            Output only the three sentences, no preamble, no headers.
            """

        case .analyticalParagraph:
            return """
            Write a single analytical paragraph (60–120 words) summarising the FRUS \
            document below. Structure the paragraph around the research focus described \
            in your standing instructions. Begin with the document type and date, then \
            develop the analysis. Output only the paragraph, no preamble, no headers.
            """

        case .structuredFields:
            let customLabel = profile.focusLabel.isEmpty ? "Research focus" : profile.focusLabel
            return """
            Summarise the FRUS document below using EXACTLY these labelled fields. \
            Each field is one concise sentence. Output only the fields in this format:

            Who: [the principal parties, officials, or countries involved]
            What: [the main subject, proposal, or decision]
            When/Where: [date and location or channel]
            Significance: [historical outcome or consequence]
            \(customLabel): [the aspect highlighted by your research focus]
            """
        }
    }

    // MARK: - Text sampling

    private struct Sample {
        let text: String
        let truncated: Bool
    }

    /// Build a representative text sample from whole paragraphs.
    /// Takes paragraphs greedily up to the budget, then appends the final
    /// paragraph (if not already included) so the model sees both the
    /// opening argument and the conclusion.
    private func buildSample(from text: String) -> Sample {
        let budget = 3500
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !paragraphs.isEmpty else { return Sample(text: text, truncated: false) }

        var sample = ""
        var truncated = false

        for (i, para) in paragraphs.enumerated() {
            if sample.count + para.count + 2 <= budget {
                if !sample.isEmpty { sample += "\n\n" }
                sample += para
            } else {
                truncated = true
                // Append the final paragraph so the model sees the conclusion
                if i < paragraphs.count - 1 {
                    sample += "\n\n[…]\n\n" + paragraphs[paragraphs.count - 1]
                }
                break
            }
        }

        return Sample(text: sample, truncated: truncated)
    }
}

// MARK: - Availability helper

extension SystemLanguageModel {
    var isAvailable: Bool {
        if case .available = availability { return true }
        return false
    }
}
