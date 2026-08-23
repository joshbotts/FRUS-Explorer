// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

// MARK: - SceneEnvironmentAuditTests

/// Fails the suite if any SwiftUI scene omits `.environment(appState)` or
/// `.modelContainer(modelContainer)`.
///
/// ## The bug this exists for
/// The About window shipped for two months as the only one of 28 scenes injecting nothing. On
/// 2026-05-17 that was harmless — `AboutView` had no environment dependency at all. On 2026-07-25,
/// S-5a moved the Research Guide row into it and added
/// `@Environment(AppState.self) private var appState`, and the omission became a hard trap: choosing
/// **FRUS Explorer ▸ About FRUS Explorer** killed the app, and because a singleton `Window` scene is
/// restorable, leaving it open at quit killed the *next launch*.
///
/// Four properties of that defect are why a test has to be the thing that catches it:
/// 1. **No compile error.** A missing environment value is a runtime trap, not a type error.
/// 2. **Never compiled by any test.** The scene lives in `#if os(macOS)`; both test bundles are
///    `platform: iOS`, and the Mac scheme has no test action. No runtime test in this repo can reach
///    that scene block.
/// 3. **Invisible to a "does it read the value?" review.** SwiftUI resolves a non-optional
///    `@Environment(SomeObservable.self)` eagerly in `EnvironmentBox.update`, during the
///    dynamic-property update phase, *before* `body` runs. The macOS `AboutView` body never reads
///    `appState` — the sole read is in the iOS arm — and it trapped anyway. The invariant is
///    "declared without injection", not "read without injection".
/// 4. **Hand-repeated 28 times.** Two modifiers, copy-pasted per scene, three of them wrong: an 11%
///    defect rate on an invariant nothing enforced.
///
/// ## Why a source-text audit and not a rendering test
/// Point 2 rules out anything that runs the scene. This follows five existing precedents in this
/// bundle (`CodingStandardsAuditTests`, `ResearchLoggingGateTests`, `ToolbarAccessibilityAuditTests`,
/// `UnreferencedDeclarationAuditTests`, `CloudKitSchemaInventoryTests`), all of which read source
/// text because the thing they protect is not otherwise reachable.
///
/// Deliberately **not** attempted: rendering `AboutView()` with no `AppState` and asserting a crash.
/// The failure is a `SIGTRAP` that takes the test host with it — unassertable from inside the
/// process, and this project has already lost time to app-host wedges.
///
/// ## What this cannot prove
/// It proves a token appears somewhere inside the scene's block, not that the modifier is attached to
/// the scene's root view — `.environment(appState)` inside a `.sheet {}` closure would satisfy it.
/// It reads one file, so a scene body extracted elsewhere escapes (guarded, loosely, by the count
/// floor below). And it says nothing about a `UIHostingController`/`NSHostingController` or an
/// AppKit-presented sheet, each of which starts a fresh environment and traps identically; the app
/// has none today.
///
/// Version history:
///   1.0 — after the About-window environment trap
struct SceneEnvironmentAuditTests {

    // MARK: - File URL Helpers

    private static let projectRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    private static let appFile: URL = projectRoot
        .appendingPathComponent("FRUSExplorer/App/FRUSExplorerApp.swift")

    private static let sourceRoot: URL = projectRoot.appendingPathComponent("FRUSExplorer")

    // MARK: - Scene block extraction

    /// One scene declaration and the source text of its content block.
    private struct SceneBlock {
        /// 1-based line of the declaration, for a failure message that can be clicked.
        let line: Int
        /// The declaration line, trimmed — enough to identify the scene in a failure.
        let declaration: String
        /// Declaration through the matching close brace.
        let body: String
    }

    /// Every scene declared in `FRUSExplorerApp.swift`, with its block.
    ///
    /// Anchored on **exactly eight leading spaces**, which is the indentation of a scene inside
    /// `var body: some Scene` and inside every `some Scene` helper property (nine at the
    /// 2026-08-23 recount — `mainWindowScene`, `archivalNeighborsScene`,
    /// `relatedDocumentsScene`, `semanticMapScene`, and the five CW-9 analytics scenes).
    /// Deeper matches — a `Window` mentioned in a comment, or a nested view — are not scenes
    /// and are not audited.
    private static func sceneBlocks(in source: String) -> [SceneBlock] {
        let lines = source.components(separatedBy: "\n")
        var blocks: [SceneBlock] = []
        for (index, line) in lines.enumerated() {
            guard line.hasPrefix("        "),               // exactly 8 spaces…
                  !line.hasPrefix("         "),             // …and not 9+
                  // Longest first: `first(where:)` with "Window" ahead of "WindowGroup" matches the
                  // prefix of every `WindowGroup`, then rejects it on the character check below —
                  // silently dropping all 11 of them. The count floor in the test caught that.
                  let kind = ["WindowGroup", "Window", "Settings"]
                      .first(where: { line.dropFirst(8).hasPrefix($0) })
            else { continue }
            // The character right after the scene type must open a call or a trailing closure,
            // so `WindowGroupSomething` or a bare identifier is not mistaken for a declaration.
            let afterKind = line.dropFirst(8 + kind.count).first
            guard afterKind == "(" || afterKind == " " || afterKind == "{" else { continue }
            blocks.append(SceneBlock(
                line: index + 1,
                declaration: line.trimmingCharacters(in: .whitespaces),
                body: braceMatchedBlock(from: lines, startingAt: index)
            ))
        }
        return blocks
    }

    /// Source text from `start` through the line holding the brace that closes the first `{`.
    ///
    /// Counts braces outside string literals only. Falls back to the rest of the file if the braces
    /// never balance, which fails loudly in the assertions rather than silently auditing nothing.
    private static func braceMatchedBlock(from lines: [String], startingAt start: Int) -> String {
        var depth = 0
        var opened = false
        for index in start..<lines.count {
            var inString = false
            var previous: Character? = nil
            for character in lines[index] {
                if character == "\"" && previous != "\\" { inString.toggle() }
                guard !inString else { previous = character; continue }
                if character == "{" { depth += 1; opened = true }
                if character == "}" { depth -= 1 }
                previous = character
            }
            if opened && depth <= 0 {
                return lines[start...index].joined(separator: "\n")
            }
        }
        return lines[start...].joined(separator: "\n")
    }

    // MARK: - Tests

    @Test("Every scene injects both appState and the model container")
    func everySceneInjectsTheSharedEnvironment() throws {
        let source = try String(contentsOf: Self.appFile, encoding: .utf8)
        let blocks = Self.sceneBlocks(in: source)

        // Anti-vacuity, in the arrange: an audit that finds nothing passes silently, which is the
        // failure mode of every source-text test. Both of these fail if the extraction breaks.
        #expect(blocks.count >= 25,
                "Found only \(blocks.count) scene declarations; the app has ~28. The extraction is broken, or scenes moved out of FRUSExplorerApp.swift — either way this audit is no longer auditing them.")
        #expect(source.contains("id: \"about\""),
                "The About window's scene id is gone. If it was renamed, update this audit; the About window is the reason it exists.")

        var offenders: [String] = []
        for block in blocks {
            var missing: [String] = []
            if !block.body.contains(".environment(appState)") { missing.append(".environment(appState)") }
            if !block.body.contains(".modelContainer(modelContainer)") { missing.append(".modelContainer(modelContainer)") }
            guard !missing.isEmpty else { continue }
            offenders.append("""
                FRUSExplorerApp.swift:\(block.line) — \(block.declaration)
                    missing: \(missing.joined(separator: " and "))
                """)
        }

        #expect(offenders.isEmpty, """
            \(offenders.count) scene(s) do not inject the shared environment:

            \(offenders.joined(separator: "\n"))

            A scene that omits `.environment(appState)` TRAPS on open if anything in its view tree
            DECLARES `@Environment(AppState.self)` — the value does not have to be read; SwiftUI
            resolves it eagerly before `body` runs. One that omits `.modelContainer(modelContainer)`
            traps if anything in its tree uses `@Query` or `\\.modelContext`.

            Add both to the scene's content view. Do not make the declaration optional to silence
            this — that converts a loud launch failure into a silent one somewhere else.
            """)
    }

    @Test("AppState is still the only Observable injected by type, so this audit's scope holds")
    func appStateIsTheOnlyTypeInjectedObservable() throws {
        // The audit above checks for one specific token, `.environment(appState)`. That is only
        // sufficient while `AppState` is the only `@Observable` injected by type. A second one would
        // make every scene an untested trap again, with this file still green — so the premise is
        // pinned here rather than left as a comment that decays.
        let fileManager = FileManager.default
        let paths = try fileManager.subpathsOfDirectory(atPath: Self.sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
        #expect(paths.count > 100,
                "Only \(paths.count) Swift files found under FRUSExplorer/; the scan path is wrong.")

        // `@Environment(SomeType.self)` — the by-type form. The keyed form, `@Environment(\.foo)`,
        // cannot trap: an EnvironmentKey always has a defaultValue.
        let pattern = try NSRegularExpression(pattern: #"@Environment\(\s*([A-Za-z_][A-Za-z0-9_.]*)\s*\.self\s*\)"#)
        var found: Set<String> = []
        for path in paths {
            let url = Self.sourceRoot.appendingPathComponent(path)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            // COMMENT LINES ARE SKIPPED. This scan cannot tell code from prose, and the pattern it
            // looks for is exactly what a doc comment WARNING about the by-type trap has to write
            // down — #1040 added one (`@Environment(Observable.self)` is resolved when the view is
            // created, not when `body` runs) and turned this test red without adding a single
            // injection. A source scan that punishes documenting the hazard it guards teaches
            // people to stop documenting it.
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                let lineText = String(line)
                let range = NSRange(lineText.startIndex..<lineText.endIndex, in: lineText)
                for match in pattern.matches(in: lineText, range: range) {
                    guard let captured = Range(match.range(at: 1), in: lineText) else { continue }
                    found.insert(String(lineText[captured]))
                }
            }
        }

        #expect(found == ["AppState"], """
            Observable types injected by `@Environment(_:.self)` are \(found.sorted()), not just \
            ["AppState"].

            `everySceneInjectsTheSharedEnvironment` only looks for `.environment(appState)`, so any \
            additional type is unaudited — and a scene missing it will trap on open exactly the way \
            the About window did. Widen that audit to cover the new type, then update this list.
            """)
    }
}
