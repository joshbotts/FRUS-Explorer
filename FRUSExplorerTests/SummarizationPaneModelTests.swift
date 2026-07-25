// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - PromptSummaryTallyTests

/// Tests the Summarization pane's counts (S-3d).
///
/// The figure these produce is the one a reader uses to decide whether a prompt is worth keeping,
/// and — before this — it was wrong in a specific way: collection headnote drafts are stored as
/// `GeneratedSummary` rows but excluded from every summary query in the app, so the pane's total
/// was larger than the number of summaries anyone could actually find.
struct PromptSummaryTallyTests {

    private let promptA = UUID()
    private let promptB = UUID()

    @Test("Document summaries are counted per prompt")
    func perPrompt() {
        let tally = PromptSummaryTally.make(summaries: [
            (promptA, false), (promptA, false), (promptB, false),
        ])
        #expect(tally.count(for: promptA) == 2)
        #expect(tally.count(for: promptB) == 1)
        #expect(tally.documentSummaries == 3)
    }

    /// The bug this fixes. A headnote draft is a `GeneratedSummary` and is not a document summary.
    @Test("Headnote drafts are excluded from the totals and counted separately")
    func headnotesExcluded() {
        let tally = PromptSummaryTally.make(summaries: [
            (promptA, false), (promptA, true), (promptB, true),
        ])
        #expect(tally.documentSummaries == 1, "a headnote draft is not a document summary")
        #expect(tally.headnoteDrafts == 2)
        #expect(tally.count(for: promptA) == 1, "the draft must not inflate its prompt's row")
        #expect(tally.count(for: promptB) == 0)
    }

    /// A prompt nobody has run is the one most likely to be up for deletion, so the row says so in
    /// words rather than showing a zero that reads like a broken counter.
    @Test("An unused prompt says so rather than reporting zero")
    func unusedPrompt() {
        let tally = PromptSummaryTally.make(summaries: [])
        #expect(tally.rowSummary(for: promptA) == "Not used yet")
    }

    @Test("Row summaries agree in number")
    func rowSummaryAgreement() {
        let one = PromptSummaryTally.make(summaries: [(promptA, false)])
        #expect(one.rowSummary(for: promptA) == "1 summary generated")
        let many = PromptSummaryTally.make(summaries: [(promptA, false), (promptA, false)])
        #expect(many.rowSummary(for: promptA) == "2 summaries generated")
    }

    @Test("An empty library tallies nothing")
    func emptyLibrary() {
        let tally = PromptSummaryTally.make(summaries: [])
        #expect(tally.documentSummaries == 0)
        #expect(tally.headnoteDrafts == 0)
        #expect(tally.byPrompt.isEmpty)
        #expect(PromptSummaryTally.empty == tally)
    }

    /// Prompts that produced nothing are absent from the dictionary rather than stored as zeroes.
    @Test("Only prompts with output are stored")
    func sparseStorage() {
        let tally = PromptSummaryTally.make(summaries: [(promptA, false)])
        #expect(tally.byPrompt.count == 1)
        #expect(tally.byPrompt[promptB] == nil)
    }
}

// MARK: - BatchRunReceiptTests

/// Tests the "Last run" row (S-3d).
///
/// The row exists so nobody has to keep a progress screen open to learn how a run ended. Its one
/// subtlety is honesty about scope: the run state lives in memory and resets on relaunch, so idle
/// must not imply that no run has ever happened.
struct BatchRunReceiptTests {

    @Test("Idle says no runs *this session*, not that none ever happened")
    func idleIsScopedToTheSession() {
        let text = BatchRunReceipt.text(for: .idle)
        #expect(text == "No runs this session")
        #expect(text.lowercased().contains("session"),
                "idle must not read as an all-time claim the pane cannot make")
    }

    @Test("A completed run reports how many documents it did, in agreement")
    func completed() {
        #expect(BatchRunReceipt.text(for: .completed(processed: 1)) == "Completed · 1 document")
        #expect(BatchRunReceipt.text(for: .completed(processed: 3)) == "Completed · 3 documents")
        #expect(BatchRunReceipt.text(for: .completed(processed: 0)) == "Completed · 0 documents")
    }

    @Test("A running batch reports its position")
    func running() {
        let text = BatchRunReceipt.text(for: .running(processed: 2, total: 7, currentDocumentId: "d1"))
        #expect(text.contains("2"))
        #expect(text.contains("7"))
    }

    /// Before a run knows its size it has no position to report, and "0 of 0" would read as failure.
    @Test("A run still enumerating says so rather than reporting 0 of 0")
    func enumerating() {
        let text = BatchRunReceipt.text(for: .running(processed: 0, total: 0, currentDocumentId: nil))
        #expect(!text.contains("0 of 0"))
        #expect(text.lowercased().contains("enumerating"))
    }

    @Test("A failure surfaces its own message")
    func failure() {
        #expect(BatchRunReceipt.text(for: .failed(errorDescription: "disk full")) == "disk full")
    }

    @Test("Only a failure reads as an error, only a cancellation as a warning")
    func stateMapping() {
        #expect(BatchRunReceipt.isFailure(.failed(errorDescription: "x")))
        #expect(!BatchRunReceipt.isFailure(.cancelled))
        #expect(!BatchRunReceipt.isFailure(.completed(processed: 1)))
        #expect(BatchRunReceipt.isCancelled(.cancelled))
        #expect(!BatchRunReceipt.isCancelled(.idle))
    }

    /// Every state has to say something, or the row renders blank.
    @Test("Every run state produces text")
    func everyStateSpeaks() {
        let states: [BackgroundSummarizationState] = [
            .idle,
            .running(processed: 1, total: 2, currentDocumentId: nil),
            .running(processed: 0, total: 0, currentDocumentId: nil),
            .completed(processed: 4),
            .cancelled,
            .failed(errorDescription: "boom"),
        ]
        for state in states {
            #expect(!BatchRunReceipt.text(for: state).isEmpty, "no text for \(state)")
        }
    }
}
