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

// MARK: - CorpusSettleHookTests

/// R-1d: an indexing-driven corpus change must reach `refreshAfterCorpusChange`.
///
/// Before R-1d, `refreshAfterCorpusChange` had 16 call sites and **all of them were in the two
/// storage hubs**. No download path called it, so a downloaded or corrected volume's people stayed
/// invisible and its read-only stores stale until the next launch.
///
/// **These are source scans, and that is a deliberate second choice.** The hook fires from
/// `endIndexingBatch`, a private method driven by a watchdog that requires a settled batch, no
/// indexing in flight and an empty download queue — reproducing that in a unit test would pin the
/// watchdog rather than the hook. A mutation sweep proved the gap real: deleting the `corpusSettled()`
/// call left the entire suite green, so R-1d's whole fix was unpinned. What a scan *can* do is fail
/// when the call is removed, which is exactly the regression to catch.
@Suite("Corpus settle hook (R-1d)")
struct CorpusSettleHookTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        // Without this a truncated read makes every negative assertion below pass.
        #expect(text.count > 10_000, "\(path) read back as \(text.count) characters")
        return text
    }

    /// `text` with comment bodies removed, so a comment cannot satisfy an assertion about code.
    private static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? "" : String($0) }
            .joined(separator: "\n")
    }

    /// The body of `func name(`, from its declaration to the next same-indent `}`.
    private static func body(of name: String, in text: String) throws -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let start = try #require(lines.firstIndex { $0.contains("func \(name)(") },
                                 "no declaration of \(name)")
        let indent = lines[start].prefix { $0 == " " }.count
        var out: [String] = []
        for line in lines[(start + 1)...] {
            if line.trimmingCharacters(in: .whitespaces) == "}",
               line.prefix { $0 == " " }.count == indent { break }
            out.append(line)
        }
        #expect(!out.isEmpty, "\(name) has an empty body — the slice is wrong")
        return out.joined(separator: "\n")
    }

    private static let appState = "FRUSExplorer/App/AppState.swift"

    /// The mutation that survived the first sweep: delete this call and nothing else fails.
    @Test("endIndexingBatch calls the settle hook")
    func batchTeardownSettlesTheCorpus() throws {
        let text = Self.code(try Self.source(Self.appState))
        let teardown = try Self.body(of: "endIndexingBatch", in: text)
        #expect(teardown.contains("corpusSettled()"),
                "endIndexingBatch must settle the corpus; body was:\n\(teardown)")
    }

    /// …and the hook must actually do the refresh, not merely exist.
    @Test("The settle hook reaches refreshAfterCorpusChange")
    func settleHookRefreshes() throws {
        let text = Self.code(try Self.source(Self.appState))
        let hook = try Self.body(of: "corpusSettled", in: text)
        #expect(hook.contains("refreshAfterCorpusChange(context:"),
                "corpusSettled must call refreshAfterCorpusChange; body was:\n\(hook)")
    }

    /// The `nil` door stays shut by TYPE, not by a guard.
    ///
    /// A `nil` context made `PersonRollupRefresh.afterCorpusChange` snapshot no overrides and stamp
    /// the empty-set fingerprint, rebuilding a rollup that ignored the reader's merges. The override
    /// ROWS survive that — only the materialised rollup goes wrong — but it is still visibly wrong
    /// until something passes a real context, so the signature refuses it.
    @Test("The refresh entry points take a non-optional context")
    func contextIsNonOptional() throws {
        let state = Self.code(try Self.source(Self.appState))
        #expect(state.contains("func refreshAfterCorpusChange(context: ModelContext)"),
                "the context must be non-optional")
        #expect(!state.contains("func refreshAfterCorpusChange(context: ModelContext?)"))

        let refresh = Self.code(try Self.source("FRUSExplorer/Models/PersonRollupRefresh.swift"))
        #expect(refresh.contains("static func afterCorpusChange(context: ModelContext,"),
                "the rollup refresh must require a context too")
        #expect(!refresh.contains("context.map {"),
                "the nil-tolerant snapshot must be gone, or the type change buys nothing")
    }

    /// The hook needs a container to get a context from, and boot must supply one.
    @Test("Boot hands AppState the container the hook needs")
    func bootWiresTheContainer() throws {
        let state = Self.code(try Self.source(Self.appState))
        #expect(state.contains("var modelContainer: ModelContainer?"),
                "AppState must hold the container")
        let app = Self.code(try Self.source("FRUSExplorer/App/FRUSExplorerApp.swift"))
        #expect(app.contains("appState.modelContainer = modelContainer"),
                "boot must wire it, or corpusSettled degrades to a connection refresh forever")
    }
}
