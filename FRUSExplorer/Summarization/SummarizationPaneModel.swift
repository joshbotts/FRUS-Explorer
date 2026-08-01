// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - PromptSummaryTally

/// How many summaries each prompt has produced (S-3d).
///
/// ## Why this exists
/// Both Summarization panes rendered "N summaries generated" on every prompt row by filtering the
/// **whole** `GeneratedSummary` table once per row, inside the view body — O(prompts × summaries)
/// on every SwiftUI render pass. And both panes embed the batch-run form, which reads the live
/// run state during body evaluation, so *every progress tick re-ran the whole scan*. One pass,
/// held as a snapshot, the same shape as `ResearchItemCounts` (S-3a).
///
/// ## Headnote drafts are not summaries
/// A collection entry's headnote draft is stored as a `GeneratedSummary` with `isHeadnoteDraft`
/// set, and is excluded from every summary query in the app. The panes' "Total Summaries" figure
/// counted them anyway, so the number a reader saw was larger than the number of document
/// summaries they could actually find. They are counted separately here and reported as such.
///
/// Version history:
///   1.0 — S-3d: initial implementation
struct PromptSummaryTally: Equatable, Sendable {

    /// Document summaries per prompt id. A prompt that has produced none is absent.
    let byPrompt: [UUID: Int]
    /// Document summaries across every prompt.
    let documentSummaries: Int
    /// Headnote drafts, which are `GeneratedSummary` rows but not document summaries.
    let headnoteDrafts: Int

    /// The state before the first fetch.
    static let empty = PromptSummaryTally(byPrompt: [:], documentSummaries: 0, headnoteDrafts: 0)

    /// Tallies one pass over the summary table.
    ///
    /// - Parameter summaries: One entry per `GeneratedSummary`: its prompt id and whether it is a
    ///   headnote draft.
    static func make(summaries: [(promptId: UUID, isHeadnoteDraft: Bool)]) -> PromptSummaryTally {
        var byPrompt: [UUID: Int] = [:]
        var documents = 0
        var headnotes = 0
        for summary in summaries {
            if summary.isHeadnoteDraft {
                headnotes += 1
            } else {
                byPrompt[summary.promptId, default: 0] += 1
                documents += 1
            }
        }
        return PromptSummaryTally(byPrompt: byPrompt,
                                  documentSummaries: documents,
                                  headnoteDrafts: headnotes)
    }

    /// Document summaries produced by `promptId`.
    func count(for promptId: UUID) -> Int { byPrompt[promptId] ?? 0 }

    /// The prompt row's second line.
    ///
    /// A prompt that has produced nothing says so in words rather than "0 summaries generated",
    /// which reads as a broken counter rather than an unused prompt.
    func rowSummary(for promptId: UUID) -> String {
        let count = count(for: promptId)
        switch count {
        case 0:
            return String(localized: "settings.summarization.prompt.unused",
                          defaultValue: "Not used yet")
        case 1:
            return String(localized: "settings.summarization.prompt.count.one",
                          defaultValue: "1 summary generated")
        default:
            return String(format: String(localized: "settings.summarization.prompt.count.many %lld",
                                         defaultValue: "%lld summaries generated"), Int64(count))
        }
    }
}

// MARK: - BatchRunReceipt

/// The "Last run" row — what the most recent batch run did (S-3d).
///
/// ## Availability first, receipt last
/// The North Star's shape for this pane is that it answers "can it work?" at the top and "did it
/// work?" at the bottom, so nobody has to keep a progress screen open to find out. This is the
/// bottom half.
///
/// ## It is honest about being per-session
/// `BackgroundSummarizationState` lives in memory and resets when the app relaunches. A row that
/// said "Last run: —" after a relaunch would imply no run had ever happened, which is false and
/// unfalsifiable from the pane. Idle says *this session* instead.
///
/// Version history:
///   1.0 — S-3d: initial implementation
enum BatchRunReceipt {

    /// What the row's trailing value reads.
    static func text(for state: BackgroundSummarizationState) -> String {
        switch state {
        case .idle:
            return String(localized: "settings.summarization.lastRun.none",
                          defaultValue: "No runs this session")
        case .running(let tally, _):
            if tally.attemptable > 0 {
                return String(format: String(localized: "settings.summarization.lastRun.running %lld %lld",
                                             defaultValue: "Running · %lld of %lld"),
                              Int64(tally.finished), Int64(tally.attemptable))
            }
            return String(localized: "settings.summarization.lastRun.enumerating",
                          defaultValue: "Running · enumerating")
        case .completed(let tally):
            if tally.isEntirelySkipped {
                return String(localized: "settings.summarization.lastRun.allSkipped",
                              defaultValue: "Nothing to do · all already summarized")
            }
            let docs = tally.succeeded == 1
                ? String(localized: "settings.summarization.lastRun.doc.one", defaultValue: "1 document")
                : String(format: String(localized: "settings.summarization.lastRun.doc.many %lld",
                                        defaultValue: "%lld documents"), Int64(tally.succeeded))
            // A run with failures is not "Completed" — the word is the whole point of #560.
            if tally.failed > 0 {
                return String(format: String(localized: "settings.summarization.lastRun.partial %lld %lld",
                                             defaultValue: "Finished · %lld summarized, %lld failed"),
                              Int64(tally.succeeded), Int64(tally.failed))
            }
            return String(localized: "settings.summarization.lastRun.completed",
                          defaultValue: "Completed · \(docs)")
        case .cancelled(let tally):
            if tally.succeeded > 0 {
                return String(format: String(localized: "settings.summarization.lastRun.cancelled.partial %lld",
                                             defaultValue: "Stopped · %lld summarized"),
                              Int64(tally.succeeded))
            }
            return String(localized: "settings.summarization.lastRun.cancelled",
                          defaultValue: "Cancelled")
        case .failed(let description):
            return description
        }
    }

    /// Whether the row describes something that went wrong. The view maps this to a glyph; the
    /// model stays free of SwiftUI so it can be tested without one.
    static func isFailure(_ state: BackgroundSummarizationState) -> Bool {
        if case .failed = state { return true }
        // A finished run that lost documents is not a success either. Before #560 this could not
        // happen — the counter advanced on failure, so a wholly-failed run rendered as `.ok`.
        if case .completed(let tally) = state, tally.failed > 0 { return true }
        return false
    }

    /// Whether the row describes a run the user stopped.
    static func isCancelled(_ state: BackgroundSummarizationState) -> Bool {
        if case .cancelled = state { return true }
        return false
    }
}

// MARK: - SummarizationPaneTally

/// Fetches `PromptSummaryTally` from a SwiftData context (S-3d).
///
/// Split from the pure tally so the arithmetic stays testable without a container, and so both
/// panes share one fetch shape.
///
/// Version history:
///   1.0 — S-3d: initial implementation
enum SummarizationPaneTally {

    /// One pass over the summary table.
    @MainActor
    static func fetch(from context: ModelContext) -> PromptSummaryTally {
        let summaries = (try? context.fetch(FetchDescriptor<GeneratedSummary>())) ?? []
        return PromptSummaryTally.make(
            summaries: summaries.map { (promptId: $0.promptId, isHeadnoteDraft: $0.isHeadnoteDraft) })
    }
}
