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

import Foundation
import Testing

/// A macOS `openWindow(value:)` must name a type macOS actually has a scene for.
///
/// ## The defect
/// The Research rail's "On the Map" tile opened with
/// `openWindow(value: SemanticMapRequest(…))`, copied from the Related Documents tile beside it.
/// That one is right — `RelatedDocumentsRequest` has a value-based `WindowGroup(for:)`. The semantic
/// map does not: on macOS it is the valueless singleton
/// `Window("Semantic Analytics", id: "frus.semanticAnalytics")`, kept that way deliberately because
/// an `MTKView` needs a window rather than a sheet. The result was a tile that logged
/// `No Scene presenting type 'SemanticMapRequest' is defined` and opened nothing.
///
/// It compiled, it shipped, and every existing guard missed it: `MacWindowFrontingTests` bans a bare
/// `openWindow(id:)` and says nothing about `openWindow(value:)`, and the feature's own tests
/// checked that the request carried the document and round-tripped — both true, and both irrelevant
/// to whether anything could present it.
///
/// ## What this checks, and what it cannot
/// `everyValueOpenHasAScene` catches a type opened by value with **no value-based scene at all** —
/// a real class of defect, and cheap to hold.
///
/// It does **not** catch the defect above, and the honest reason is worth recording rather than
/// papering over. `SemanticMapRequest` *does* have a `WindowGroup(for:)`; it lives in a
/// platform-neutral `private var semanticMapScene` that only the **iOS** scene body references. The
/// gating is structural — which `@SceneBuilder` includes it — not lexical, so no `#if` walk can see
/// it, and a scan would have to resolve scene composition to know. Verified by mutation: with the
/// bug restored, this test passes and only `railUsesHandOffForTheMap` fails.
///
/// So the general scan is the wide net and **the hand-written pin is the guard for this bug**. A
/// platform projection is still applied, because it costs little and narrows the net honestly; it
/// simply cannot reach a scene gated by composition.
///
/// Version history:
///   1.0 — build 42: after "On the Map" failed to open on macOS
@Suite("macOS window routing")
struct MacWindowRoutingTests {

    private static var appRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer")
    }

    private static func swiftFiles() -> [URL] {
        (FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []).sorted { $0.path < $1.path }
    }

    /// Strips `//` line comments so prose quoting a call is not mistaken for one.
    private static func stripped(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { line -> String in
                guard let slashes = line.range(of: "//") else { return line }
                return String(line[..<slashes.lowerBound])
            }
            .joined(separator: "\n")
    }

    /// Which lines of a file the **macOS** target actually compiles.
    ///
    /// Narrows the net to what macOS actually builds. Note the limit measured while writing this:
    /// it sees `#if os(iOS)` blocks and nothing else, so a scene included only by an iOS
    /// `@SceneBuilder` — which is how the semantic map's group is iOS-only — still reads as
    /// available. See the suite comment.
    ///
    /// Unknown conditions (`#if DEBUG`, feature flags) count as compiled — leniency is the safe
    /// direction for anything that is not a platform gate.
    private static func macOSLines(_ source: String) -> Set<Int> {
        var compiled: Set<Int> = []
        var stack: [Bool] = []
        func armIsMac(_ condition: String) -> Bool {
            if condition.contains("os(macOS)") { return true }
            if condition.contains("os(iOS)") || condition.contains("os(visionOS)") { return false }
            return true
        }
        for (index, raw) in source.components(separatedBy: .newlines).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if ") {
                stack.append(armIsMac(line))
            } else if line.hasPrefix("#elseif ") {
                if !stack.isEmpty { stack[stack.count - 1] = armIsMac(line) }
            } else if line == "#else" {
                if !stack.isEmpty { stack[stack.count - 1].toggle() }
            } else if line.hasPrefix("#endif") {
                if !stack.isEmpty { stack.removeLast() }
            } else if !stack.contains(false) {
                compiled.insert(index + 1)
            }
        }
        return compiled
    }

    /// Keeps only the lines macOS compiles, preserving line numbers.
    private static func macOSOnly(_ source: String) -> String {
        let lines = source.components(separatedBy: .newlines)
        let keep = macOSLines(source)
        return lines.enumerated()
            .map { keep.contains($0.offset + 1) ? $0.element : "" }
            .joined(separator: "\n")
    }

    /// Types registered as value-based scenes **in code macOS compiles**.
    private static func valueSceneTypes(_ sources: [String]) -> Set<String> {
        var found: Set<String> = []
        // Matches across the optional leading arguments a scene may carry — an id, a localized
        // title, or both, on any number of lines. The first version required `for:` to follow
        // `WindowGroup(` almost immediately and so missed
        // `WindowGroup(String(localized:…), for: ProjectHomeRequest.self)`, reporting a registered
        // type as an offender. A scan that cries wolf about correct code gets deleted, not fixed.
        guard let pattern = try? Regex(#"(?s)WindowGroup\(.{0,240}?for:\s*([A-Za-z_][A-Za-z0-9_.]*)\.self"#)
        else { return found }
        for source in sources {
            for match in source.matches(of: pattern) {
                found.insert(String(match.output[1].substring ?? ""))
            }
        }
        return found
    }

    /// Every `openWindow(value: SomeType(` call, with the file it appears in.
    private static func valueOpenCalls(_ files: [(URL, String)]) -> [(type: String, file: String)] {
        guard let pattern = try? Regex(#"openWindow\(\s*value:\s*([A-Za-z_][A-Za-z0-9_.]*)\s*\("#)
        else { return [] }
        var calls: [(String, String)] = []
        for (url, source) in files {
            for match in macOSOnly(stripped(source)).matches(of: pattern) {
                calls.append((String(match.output[1].substring ?? ""), url.lastPathComponent))
            }
        }
        return calls
    }

    @Test("Every openWindow(value:) names a type with a value-based scene")
    func everyValueOpenHasAScene() throws {
        let files = try Self.swiftFiles().map { ($0, try String(contentsOf: $0, encoding: .utf8)) }
        let scenes = Self.valueSceneTypes(files.map { Self.macOSOnly($0.1) })
        try #require(!scenes.isEmpty, "no WindowGroup(for:) found — the scene matcher is broken")
        // A control: this type is known to have one, so an empty/incorrect match set fails loudly
        // rather than passing everything.
        // Controls covering BOTH declaration shapes: a bare `WindowGroup(for:)` and one carrying a
        // title first. The second is the shape the first matcher missed.
        for control in ["RelatedDocumentsRequest", "ProjectHomeRequest", "DocumentWindowID"] {
            try #require(scenes.contains(control), """
                The scene matcher missed \(control), which is registered. A matcher that under-counts \
                scenes reports correct code as broken. Found: \(scenes.sorted())
                """)
        }

        let offenders = Self.valueOpenCalls(files).filter { !scenes.contains($0.type) }
        #expect(offenders.isEmpty, """
            \(offenders.count) call(s) open a window by value for a type with no WindowGroup(for:):

            \(offenders.map { "  \($0.file): openWindow(value: \($0.type)(…))" }.joined(separator: "\n"))

            SwiftUI reports this only at runtime — "No Scene presenting type '…' is defined" — and \
            nothing opens. If the destination is a singleton `Window(id:)`, hand the request through \
            its AppState slot and raise it with `openWindow.fronting(id:)` instead.
            """)
    }

    /// The specific route, pinned so it cannot regress to the shape that failed.
    @Test("The rail opens the semantic map through the hand-off slot, not by value")
    func railUsesHandOffForTheMap() throws {
        let source = Self.stripped(try String(
            contentsOf: Self.appRoot.appending(path: "DocumentView/ResearchRailView.swift"),
            encoding: .utf8))
        #expect(!source.contains("openWindow(value: SemanticMapRequest"), """
            The rail opens the semantic map by value again. macOS has no value-based scene for it — \
            it is the valueless singleton Window(id: "frus.semanticAnalytics"), deliberately, \
            because an MTKView needs a window rather than a sheet.
            """)
        #expect(source.contains("appState.openSemanticMap("), """
            The rail no longer routes the map request through AppState.openSemanticMap(_:from:), \
            which is what puts it in the slot the window consumes on both platforms.
            """)
        #expect(source.contains(#"fronting(id: "frus.semanticAnalytics")"#), """
            The rail sets the hand-off but never raises the window, so a reveal would do nothing \
            visible when the window is closed.
            """)
    }

    /// The continuation must be re-appliable, or only the first reveal works.
    @Test("A new continuation replaces the applied one rather than being ignored")
    func continuationIsKeyedByValue() throws {
        let source = Self.stripped(try String(
            contentsOf: Self.appRoot.appending(path: "Semantic/Map/SemanticMapSpikeView.swift"),
            encoding: .utf8))
        #expect(!source.contains("hasAppliedContinuation"), """
            The continuation guard is a Bool again. The macOS map window is a SINGLETON, so a second \
            reveal hands the same live view a new request — a flag that only remembers THAT one was \
            applied refuses it, and every reveal after the first silently does nothing.
            """)
        #expect(source.contains("appliedContinuation"),
                "the continuation should be remembered by value")
        #expect(source.contains("onChange(of: continued)"), """
            Nothing re-applies a continuation that arrives at an already-open map. The `.task` has \
            already run by then and will not run again.
            """)
    }
}
