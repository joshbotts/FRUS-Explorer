// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - SummaryPromptResolutionTests

/// Which prompt a regeneration runs (R-5 P3b-6, design Q-8 e).
///
/// Every fixture is built so that the WRONG rule would pick a different row than the right one —
/// otherwise a test passes because the expected prompt happened to be the oldest, or the only
/// standard, rather than because the rule asked the right question.
///
/// Version history:
///   1.0 — R-5 P3b-6: initial implementation
@Suite("Summary prompt resolution — which prompt a regenerate runs")
struct SummaryPromptResolutionTests {

    /// Returns the CONTAINER, never a bare `mainContext`. `try makeContainer().mainContext`
    /// releases the container on the same line and the context then traps — which is not a test
    /// failure but a runner CRASH, and the run reports "0 tests" while looking green.
    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: SummarizationPrompt.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    @discardableResult
    private func prompt(_ context: ModelContext, _ name: String,
                        standard: Bool, created: Date?) -> SummarizationPrompt {
        let p = SummarizationPrompt(name: name, promptText: "t", isStandard: standard)
        p.createdAt = created
        context.insert(p)
        return p
    }

    private func date(_ t: TimeInterval) -> Date { Date(timeIntervalSinceReferenceDate: t) }

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("FRUSExplorer/\(relative)"), encoding: .utf8)
    }

    /// R-5 P3b-6. The rule above is pure and fully tested; what a scan can add is that the three
    /// surfaces actually ASK it, and ask it the right question. A surface that resolved correctly
    /// and then regenerated with something else would pass every test in this suite.
    @Test("P3b-6 wiring: all three surfaces resolve through the shared rule, keyed on their own summary")
    func p3b6Wiring() throws {
        // macOS: the ACTIVE summary's prompt, not "whichever is oldest".
        let mac = try Self.source("App/SupportingViews.swift")
        #expect(mac.contains("SummarizationPrompt.resolve(preferredId: vm.activeSummary?.promptId, in: modelContext)"))
        #expect(!mac.contains("FetchDescriptor<SummarizationPrompt>(sortBy: [SortDescriptor(\\.createdAt)])"),
                "the oldest-prompt fetch this phase replaces must be gone")
        #expect(!mac.contains("Text(\"· custom prompt\")"),
                "the label that called every summary custom must be gone")

        // iOS: THIS strip's summary, not a nil preference — a nil would resolve to the fallback and
        // regenerate every summary with a standard prompt.
        let ios = try Self.source("DocumentView/DocumentView.swift")
        #expect(ios.contains("SummarizationPrompt.resolve(preferredId: summary.promptId, in: modelContext)"))
        // Both surfaces must warn before substituting; the enum's own doc makes it an obligation.
        #expect(ios.contains("summary.block.regenerate.fallback %@"),
                "iOS must warn before substituting a prompt, as macOS does")
        #expect(mac.contains("summary.block.regenerate.fallback %@"))

        // The Collections composer asks the same question rather than keeping its own copy.
        let inspector = try Self.source("Collections/CollectionEntryInspector.swift")
        #expect(inspector.contains("SummarizationPrompt.resolve("))
        #expect(!inspector.contains("predicate: #Predicate { $0.isStandard == true },"),
                "the inspector's private fallback, which carried the same nil-date trap, must be gone")
    }

    /// The summary's OWN prompt wins. The fixture makes it neither the oldest nor a standard one,
    /// so a rule that reached for either would return a different row.
    @Test("A live preferred id resolves to that prompt, even when it is neither oldest nor standard")
    @MainActor
    func preferredWins() throws {
        let container = try container()
        let context = container.mainContext
        prompt(context, "Standard Summary", standard: true, created: date(100))
        let mine = prompt(context, "My close reading", standard: false, created: date(900))
        try context.save()

        guard case .requested(let got) = SummarizationPrompt.resolve(preferredId: mine.id, in: context) else {
            Issue.record("expected .requested"); return
        }
        #expect(got.id == mine.id)
        #expect(got.name == "My close reading")
    }

    /// A summary can outlive its prompt: every delete site is a bare `modelContext.delete`, and
    /// only the seeder ever repoints, and only for duplicate standards. The fallback must be the
    /// oldest STANDARD — the fixture plants an older CUSTOM prompt, which is what today's macOS
    /// code returns, because its fetch carries no `isStandard` predicate at all.
    @Test("A dangling id falls back to the oldest standard, never to an older custom prompt")
    @MainActor
    func danglingFallsBackToStandard() throws {
        let container = try container()
        let context = container.mainContext
        prompt(context, "An old prompt of mine", standard: false, created: date(10))
        prompt(context, "Standard Summary", standard: true, created: date(500))
        prompt(context, "Standard Brief", standard: true, created: date(700))
        try context.save()

        guard case .standardFallback(let got) =
                SummarizationPrompt.resolve(preferredId: UUID(), in: context) else {
            Issue.record("expected .standardFallback"); return
        }
        #expect(got.name == "Standard Summary", "the OLDEST standard, not the oldest row")
    }

    /// `createdAt` is optional and legacy or synced rows really do carry nil — the seeder's own
    /// keeper rule exists for that case. A raw ascending sort puts NULL FIRST, so a dateless row
    /// would win; the rule coerces nil to `.distantFuture` so it loses instead.
    @Test("A standard prompt with no createdAt does not win the fallback")
    @MainActor
    func nilDatedStandardLoses() throws {
        let container = try container()
        let context = container.mainContext
        prompt(context, "Dateless import", standard: true, created: nil)
        prompt(context, "Standard Summary", standard: true, created: date(500))
        try context.save()

        guard case .standardFallback(let got) =
                SummarizationPrompt.resolve(preferredId: nil, in: context) else {
            Issue.record("expected .standardFallback"); return
        }
        #expect(got.name == "Standard Summary")
    }

    /// Erase Everything deletes every prompt and the seeder runs only at launch, so an empty store
    /// is a real state for the rest of that session. The caller must be able to say so rather than
    /// silently doing nothing, which is what the code this replaces did.
    @Test("An empty store resolves to unavailable, not to a crash or a silent nil")
    @MainActor
    func emptyStoreIsUnavailable() throws {
        let container = try container()
        let context = container.mainContext
        guard case .unavailable = SummarizationPrompt.resolve(preferredId: UUID(), in: context) else {
            Issue.record("expected .unavailable"); return
        }
        guard case .unavailable = SummarizationPrompt.resolve(preferredId: nil, in: context) else {
            Issue.record("expected .unavailable for a nil preference too"); return
        }
    }

    /// A reader with an empty store is told to add a prompt in Settings — and a prompt they add is
    /// NOT standard. A standards-only fallback would still report "no prompt is available" after
    /// they had followed the instruction exactly, so the app would be telling them to do something
    /// that does not work.
    @Test("With no standard prompt, the fallback uses what there is rather than dead-ending")
    @MainActor
    func fallsBackToACustomPromptWhenNoStandardExists() throws {
        let container = try container()
        let context = container.mainContext
        prompt(context, "The one I just added", standard: false, created: date(500))
        prompt(context, "Another of mine", standard: false, created: date(900))
        try context.save()

        guard case .standardFallback(let got) =
                SummarizationPrompt.resolve(preferredId: UUID(), in: context) else {
            Issue.record("expected a fallback, not .unavailable"); return
        }
        #expect(got.name == "The one I just added", "the oldest available prompt")
    }

    /// A standard is still preferred when one exists — the substitute should be a prompt the app
    /// shipped, not one the reader wrote, whenever there is a choice.
    @Test("A standard prompt still wins the fallback over an older custom one")
    @MainActor
    func standardStillPreferredWhenPresent() throws {
        let container = try container()
        let context = container.mainContext
        prompt(context, "Mine, and older", standard: false, created: date(10))
        prompt(context, "Standard Summary", standard: true, created: date(500))
        try context.save()

        guard case .standardFallback(let got) =
                SummarizationPrompt.resolve(preferredId: UUID(), in: context) else {
            Issue.record("expected .standardFallback"); return
        }
        #expect(got.name == "Standard Summary")
    }

    /// `min(by:)` is not documented as stable, and the seeder inserts its standards in one tick, so
    /// equal dates are the ordinary case rather than a contrived one. Without a total order the
    /// prompt NAMED and the prompt RUN could differ between two reads of the same store.
    @Test("Two standards created in the same instant resolve to the same one every time")
    @MainActor
    func tiesAreBrokenTotally() throws {
        let container = try container()
        let context = container.mainContext
        let a = prompt(context, "Standard A", standard: true, created: date(500))
        let b = prompt(context, "Standard B", standard: true, created: date(500))
        try context.save()

        let expected = a.id.uuidString < b.id.uuidString ? a.id : b.id
        for _ in 0..<5 {
            guard case .standardFallback(let got) =
                    SummarizationPrompt.resolve(preferredId: UUID(), in: context) else {
                Issue.record("expected .standardFallback"); return
            }
            #expect(got.id == expected)
        }
    }

    /// The label beside a summary names the prompt that MADE it, so a substitute must never appear
    /// there — that would attribute the summary to a prompt which never wrote a word of it.
    @Test("Only the requested prompt may be printed as provenance")
    @MainActor
    func onlyRequestedIsProvenance() throws {
        let container = try container()
        let context = container.mainContext
        let mine = prompt(context, "My close reading", standard: false, created: date(900))
        prompt(context, "Standard Summary", standard: true, created: date(100))
        try context.save()

        #expect(SummarizationPrompt.resolve(preferredId: mine.id, in: context).provenanceName
                == "My close reading")
        #expect(SummarizationPrompt.resolve(preferredId: UUID(), in: context).provenanceName == nil,
                "a substitute must not be named as the summary's own prompt")
        #expect(SummarizationPrompt.resolve(preferredId: nil, in: context).provenanceName == nil)
        // …but it IS the prompt a regeneration would run, and the caller needs that separately.
        #expect(SummarizationPrompt.resolve(preferredId: UUID(), in: context).prompt?.name
                == "Standard Summary")
    }
}
