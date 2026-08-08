// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
import Foundation
@testable import FRUSExplorer

/// On macOS, opening a document must never silently do nothing (#748).
///
/// ## The invariant
/// `AppState.openDocument(_:from:mintWindow:)` resolves through the provenance chain and **mints a
/// standalone window when no document host is live**. `openBrowseDocument` does not: its macOS arm
/// writes `pendingBrowseDocument`, whose only consumers are the document hosts' `onAppear` drains.
/// With zero hosts mounted — an ordinary state, since ⌘W closes the main window while Project Home
/// and the tool windows keep the app running — that write is observed by nobody.
///
/// The failure is worse than a no-op. The value is not discarded: it sits in `AppState` until the
/// next host mounts, so the fresh window the user opens minutes or days later immediately navigates
/// itself to a long-forgotten document. Nothing about either half looks like a bug on its own.
///
/// ## Why this is a source-reading test
/// `AppStateTests` already proves the *model* mints correctly when no host is live. That was true
/// throughout the bug: the defect was that one producer never called the minting API. No behavioural
/// test of `AppState` can see a call that isn't made, so the invariant has to be asserted about the
/// producers — the same reason `CodingStandardsAuditTests` and `ResetInventoryTests` read source.
///
/// `AppState.pendingBrowseDocument`'s doc comment asserted this exact invariant ("on macOS every
/// producer now routes directly through `openDocument`") and was **false for two releases** while
/// `ProjectHomeView` contradicted it. A comment cannot fail a build; this can.
///
/// Version history:
///   1.0 — Session 2026-08-08: #748
@Suite("macOS document-open routing")
struct MacDocumentOpenRoutingTests {

    // MARK: - Conditional-compilation scope analysis

    /// One `#if` frame: its condition, and whether we are currently inside its `#else`.
    private struct ConditionFrame {
        let condition: String
        var inElse: Bool
    }

    /// Lines containing `needle` that are **compiled on macOS**.
    ///
    /// Tracks `#if` / `#elseif` / `#else` / `#endif` nesting rather than pattern-matching nearby
    /// lines. That distinction is the whole test: the five sibling producers all sit a few lines
    /// below a `#if os(macOS)` — inside its `#else` — so a naive "nearest preceding directive" scan
    /// reports every one of them as a macOS writer and the suite becomes noise. (I made exactly that
    /// mistake by hand while investigating #748, and it inverted the answer.)
    ///
    /// Non-platform conditions (`DEBUG`, feature flags) are tracked for nesting but do not affect
    /// platform reachability.
    static func macOSReachableLines(in source: String, containing needle: String) -> [(line: Int, text: String)] {
        var stack: [ConditionFrame] = []
        var hits: [(Int, String)] = []

        for (index, raw) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let text = raw.trimmingCharacters(in: .whitespaces)

            if text.hasPrefix("#if ") {
                stack.append(ConditionFrame(condition: String(text.dropFirst(4)), inElse: false))
            } else if text.hasPrefix("#elseif ") {
                if !stack.isEmpty {
                    stack[stack.count - 1] = ConditionFrame(condition: String(text.dropFirst(8)), inElse: false)
                }
            } else if text == "#else" {
                if !stack.isEmpty { stack[stack.count - 1].inElse = true }
            } else if text.hasPrefix("#endif") {
                if !stack.isEmpty { stack.removeLast() }
            } else if text.contains(needle) && !text.hasPrefix("//") {
                var reachable = true
                for frame in stack {
                    if frame.condition.contains("os(macOS)") {
                        reachable = reachable && !frame.inElse
                    } else if frame.condition.contains("os(iOS)") {
                        reachable = reachable && frame.inElse
                    }
                }
                if reachable { hits.append((index + 1, text)) }
            }
        }
        return hits
    }

    // MARK: - Fixtures

    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer")
    }

    /// Every `.swift` file under `FRUSExplorer/`, except `AppState.swift` itself (which *defines*
    /// the channel and legitimately writes it in `unregisterHost`'s demotion).
    private static func producerSources() throws -> [(path: String, source: String)] {
        let root = appSourceRoot
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            Issue.record("could not enumerate \(root.path)")
            return []
        }
        var result: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            if url.lastPathComponent == "AppState.swift" { continue }
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            result.append((relative, try String(contentsOf: url, encoding: .utf8)))
        }
        return result.sorted { $0.0 < $1.0 }
    }

    // MARK: - The analyser earns its trust first

    @Test("The scope analyser sees an #else branch as the opposite platform")
    func analyserUnderstandsElse() {
        // This is the exact shape of the five correct producers. If the analyser gets it wrong the
        // real assertion below is either vacuous or a false alarm, so pin it on a literal.
        let source = """
            func open() {
                #if os(macOS)
                appState.openDocument(entry, from: .global, using: openWindow)
                #else
                appState.openBrowseDocument(entry, from: sceneID)
                #endif
            }
            """
        let hits = Self.macOSReachableLines(in: source, containing: "openBrowseDocument(")
        #expect(hits.isEmpty, "a call in the #else of #if os(macOS) is iOS-only, not macOS-reachable")

        let routed = Self.macOSReachableLines(in: source, containing: "openDocument(entry")
        #expect(routed.count == 1, "the call in the #if os(macOS) branch IS macOS-reachable")
    }

    @Test("The scope analyser catches an unguarded call — the #748 shape")
    func analyserCatchesTheRealBug() {
        // ProjectHomeView as it actually shipped: only the iOS-specific line was guarded, and the
        // openBrowseDocument beside it ran on both platforms.
        let source = """
            func open() {
                #if os(iOS)
                appState.openTab(.browse, from: sceneID)
                #endif
                appState.openBrowseDocument(entry, from: sceneID)
            }
            """
        let hits = Self.macOSReachableLines(in: source, containing: "openBrowseDocument(")
        #expect(hits.count == 1, "an unguarded call after an #if os(iOS) block IS compiled on macOS")
    }

    @Test("The scope analyser ignores non-platform conditions but still nests through them")
    func analyserHandlesDebugBlocks() {
        let source = """
            #if os(iOS)
            #if DEBUG
            print("noise")
            #endif
            appState.openBrowseDocument(entry, from: sceneID)
            #endif
            appState.openBrowseDocument(other, from: sceneID)
            """
        let hits = Self.macOSReachableLines(in: source, containing: "openBrowseDocument(")
        #expect(hits.count == 1, "the DEBUG block must not desynchronise the #if os(iOS) frame")
        #expect(hits.first?.text.contains("other") == true,
                "only the call after the #endif is macOS-reachable")
    }

    // MARK: - The invariant

    @Test("No macOS producer writes the legacy browse channel instead of routing through openDocument")
    func noMacProducerBypassesTheMint() throws {
        var offenders: [String] = []
        for (path, source) in try Self.producerSources() {
            for hit in Self.macOSReachableLines(in: source, containing: "openBrowseDocument(") {
                offenders.append("\(path):\(hit.line)")
            }
        }
        #expect(offenders.isEmpty, """
            These macOS-compiled producers call appState.openBrowseDocument(...), which writes \
            pendingBrowseDocument and is delivered ONLY by a mounted document host's drain: \
            \(offenders.joined(separator: ", ")).
            With no host mounted the click does nothing, and then fires as a surprise navigation \
            when the user next opens a window (#748). Use \
            appState.openDocument(entry, from: <source>, using: openWindow) inside \
            #if os(macOS) — it mints a standalone window when no host is live — and keep \
            openBrowseDocument in the #else branch for iOS.
            """)
    }

    @Test("Project Home routes through the minting API on macOS and the tab hand-off on iOS")
    func projectHomeUsesBothArms() throws {
        // Named specifically, because the invariant above passes just as well if someone deletes
        // the call site entirely — which would fix the dead-drop by removing the feature.
        let source = try String(
            contentsOf: Self.appSourceRoot.appendingPathComponent("ProjectContext/ProjectHomeView.swift"),
            encoding: .utf8)

        let minting = Self.macOSReachableLines(in: source, containing: "appState.openDocument(entry, from: .global")
        #expect(minting.count == 1, """
            ProjectHomeView must open documents through appState.openDocument(entry, from: .global, \
            using: openWindow) on macOS, so a click with no document window open mints one (#748).
            """)

        // And the iOS arm must survive: it needs the tab switch, since Project Home is reached from
        // the Settings tab and the document lands in Browse.
        #expect(source.contains("appState.openTab(.browse, from: sceneID)"),
                "the iOS arm must still bring the Browse tab forward, or the tap looks like a no-op")
        #expect(source.contains("appState.openBrowseDocument(entry, from: sceneID)"),
                "the iOS arm must still hand the document off to BrowserView")
    }

    @Test("The five sibling producers keep their macOS minting route")
    func siblingProducersStillRoute() throws {
        // These are the producers ProjectHomeView was supposed to match. Asserting them here means
        // a future edit that regresses one of them back to the legacy channel fails with its own
        // name attached, rather than as an anonymous entry in the invariant above.
        let expected = [
            "Research/ResearchView.swift",
            "RelatedDocuments/RelatedDocumentsView.swift",
            "SourceExplorer/ArchivalNeighborsSheet.swift",
            "History/HistoryView.swift",
            "Analytics/CrossReferenceAnalyticsView.swift",
        ]
        for relative in expected {
            let source = try String(
                contentsOf: Self.appSourceRoot.appendingPathComponent(relative), encoding: .utf8)
            let routed = Self.macOSReachableLines(in: source, containing: "appState.openDocument(")
            #expect(!routed.isEmpty,
                    "\(relative) must still route macOS document opens through appState.openDocument (#748)")
        }
    }
}
