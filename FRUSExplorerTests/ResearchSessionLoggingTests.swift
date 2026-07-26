// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - ResearchSessionLoggingTests

/// Pins that the research trail's writes actually persist without an explicit `save()`.
///
/// ## What this used to test, and why it still matters
/// `AppState.logEvent(_:)` wrote into `AppState.loggingContext`, a `ModelContext` created by hand
/// at boot, and nothing ever called `save()` on it. That reads like a bug — a hand-made context is
/// widely believed not to autosave — and it was not one: on this SDK `autosaveEnabled` is `true`
/// by default, so the records landed. The first version of this file asserted the opposite and was
/// wrong, which is why the fact is measured here rather than reasoned about.
///
/// Wave R-2a removed both `logEvent` and the hand-made context. The **fact** is still load-bearing
/// and now applies more widely, not less: all three trail writers
/// (`DocumentViewModel.recordReadingHistory`, the two `recordSearchHistory`s, and
/// `ExportHistoryRecorder.record`) insert into the view's `@Environment(\.modelContext)` and
/// return without saving. If autosave ever stopped, every one of them would silently stop
/// recording and no screen would change until relaunch.
///
/// Version history:
///   1.0 — initial implementation (the `logEvent` autosave question)
///   1.1 — Wave R-2a: retargeted at the three surviving writers; the `logEvent`-specific tests are
///          gone with the method, and the preference-default test is left to
///          `ResearchLoggingGateTests`, which owns the gate
struct ResearchSessionLoggingTests {

    /// The app's real schema. `makeTestContainer()` passes `cloudKitDatabase: .none`, per the
    /// recorded hazard: an entitled test host otherwise spins up real sync and crashes.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer.makeTestContainer()
    }

    /// The load-bearing fact, at the context the writers actually use.
    @Test("The main context autosaves, so a trail writer that never saves still records")
    @MainActor
    func mainContextAutosaves() throws {
        let container = try makeContainer()
        #expect(container.mainContext.autosaveEnabled == true)
    }

    /// And a freshly made context autosaves too — recorded so a future reader does not "fix" a
    /// writer by adding an explicit save on the theory that only `mainContext` persists.
    @Test("A hand-made context autosaves as well")
    @MainActor
    func handMadeContextAutosaves() throws {
        let container = try makeContainer()

        let scratch = ModelContext(container)
        #expect(scratch.autosaveEnabled == true)
        scratch.insert(ExportHistoryEntry(format: "pdf", documentCount: 1))
        #expect(scratch.insertedModelsArray.count == 1)
    }

    /// A saved insert reaches other readers of the same store — which is what the History surface,
    /// Project Home and the derived session log all are.
    @Test("A saved insert is visible to another context")
    @MainActor
    func explicitSavePersists() throws {
        let container = try makeContainer()

        let writer = ModelContext(container)
        writer.insert(SearchHistoryEntry(queryText: "quadripartite", resultCount: 31))
        try writer.save()

        let reader = ModelContext(container)
        #expect(try reader.fetch(FetchDescriptor<SearchHistoryEntry>()).count == 1)
    }
}
