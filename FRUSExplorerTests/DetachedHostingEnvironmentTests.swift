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

/// Content handed to a **detached hosting modifier** must carry the environment in with it.
///
/// ## The defect (#950)
/// `.tabViewSidebarFooter`'s content is hosted by the sidebar container, not by the `TabView`'s
/// content hierarchy — so **none** of the modifiers applied to the `TabView` reach it, including
/// the scene's `.environment(appState)`. `SidebarShortcuts` opens with
/// `@Environment(AppState.self)`, which SwiftUI resolves **eagerly on declaration** rather than
/// lazily in `body`, so building the footer trapped outright:
///
/// > Fatal error: No Observable object of type AppState found.
///
/// It reproduced only on iPad and only while **resizing the main window**, because the footer
/// exists solely in the sidebar representation, which is width-dependent. Every scene in the app
/// injects `appState` correctly; this hierarchy simply is not descended from one — which is why an
/// audit of the scenes (all 36 inject) found nothing.
///
/// ## Why a source scan
/// The failure needs an iPad wide enough for the sidebar. It cannot be reached from a unit test,
/// and a simulator without the resize gesture will not build the footer either. The structural
/// property — *this modifier's content re-injects what it needs* — is visible in source and is the
/// thing that was missing, so that is what this asserts.
///
/// Version history:
///   1.0 — #950: after the iPad resize crash
@Suite("Detached hosting modifiers carry the environment")
struct DetachedHostingEnvironmentTests {

    /// Modifiers whose content SwiftUI hosts outside the modified view's own hierarchy.
    ///
    /// Kept as a list because the next one added is the next #950. A modifier belongs here when its
    /// content is rendered by a *container* (a sidebar, an ornament, a separate presentation) that
    /// is not a descendant of the view the modifier is attached to.
    private static let detachedModifiers = [
        "tabViewSidebarHeader",
        "tabViewSidebarFooter",
        "tabViewBottomAccessory",
    ]

    private static var appRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer")
    }

    private static func swiftSources() throws -> [(name: String, text: String)] {
        let urls = (FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []).sorted { $0.path < $1.path }
        return try urls.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    /// Strips `//` comments so prose describing a modifier is never mistaken for a use of it —
    /// the failure that let a mutation survive `CollocationWiringAuditTests`.
    private static func stripped(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { line -> String in
                guard let slashes = line.range(of: "//") else { return line }
                return String(line[..<slashes.lowerBound])
            }
            .joined(separator: "\n")
    }

    /// Views that trap on declaration if `AppState` is not an ancestor.
    private static func appStateReaders(_ sources: [(name: String, text: String)]) -> Set<String> {
        var readers: Set<String> = []
        guard let decl = try? Regex(#"(?:struct|final class|class)\s+([A-Za-z_][A-Za-z0-9_]*)"#)
        else { return readers }
        for (_, text) in sources {
            let code = stripped(text)
            // Walk declarations in order; a type "reads" AppState if the text between its
            // declaration and the next one contains the environment property.
            let matches = Array(code.matches(of: decl))
            for (i, m) in matches.enumerated() {
                let start = m.range.upperBound
                let end = i + 1 < matches.count ? matches[i + 1].range.lowerBound : code.endIndex
                if code[start..<end].contains("@Environment(AppState.self)") {
                    readers.insert(String(m.output[1].substring ?? ""))
                }
            }
        }
        return readers
    }


    /// The body of a modifier's trailing closure, bounded by BRACE DEPTH rather than by a
    /// character count.
    ///
    /// **A fixed window was wrong twice.** At 900 characters it stopped short of the footer's third
    /// injection, so deleting `\.sceneID` went uncaught. Widened to 2400 it then ran *past* the
    /// closure and swallowed the `TabView`'s own `.environment(\.sceneID, …)` a few lines below —
    /// so the assertion passed by reading a different call site's modifier. Both were found by
    /// mutation, and both are the same mistake: a closure ends where its brace closes, and nothing
    /// else is a safe proxy.
    private static func closureBody(after start: String.Index, in code: String) -> String {
        guard let open = code[start...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var i = open
        while i < code.endIndex {
            if code[i] == "{" { depth += 1 }
            if code[i] == "}" {
                depth -= 1
                if depth == 0 { return String(code[open...i]) }
            }
            i = code.index(after: i)
        }
        return String(code[open...])
    }

    @Test("Every detached-hosting call site re-injects the environment it needs")
    func detachedContentReinjectsAppState() throws {
        let sources = try Self.swiftSources()
        let readers = Self.appStateReaders(sources)
        // Control: the type that actually trapped must be recognised as a reader, or the scan is
        // measuring nothing.
        try #require(readers.contains("SidebarShortcuts"), """
            The AppState-reader scan did not find SidebarShortcuts, which is the view #950 crashed \
            in. The declaration matcher is broken, so every assertion below is vacuous.
            """)

        var offenders: [String] = []
        for (name, text) in sources {
            let code = Self.stripped(text)
            for modifier in Self.detachedModifiers {
                var search = code.startIndex
                while let hit = code.range(of: ".\(modifier)", range: search..<code.endIndex) {
                    search = hit.upperBound
                    let body = Self.closureBody(after: hit.upperBound, in: code)
                    // Which AppState-reading views does this footer mount?
                    let mounted = readers.filter { body.contains("\($0)(") }
                    guard !mounted.isEmpty else { continue }
                    if !body.contains(".environment(appState)") {
                        offenders.append(
                            "\(name): .\(modifier) mounts \(mounted.sorted().joined(separator: ", "))"
                            + " without .environment(appState)")
                    }
                }
            }
        }
        #expect(offenders.isEmpty, """
            \(offenders.count) detached-hosting call site(s) mount a view that reads \
            @Environment(AppState.self) without re-injecting it:

            \(offenders.joined(separator: "\n"))

            SwiftUI hosts this content outside the modified view's hierarchy, so the scene's \
            .environment(appState) does not reach it. @Environment(Observable.self) resolves \
            eagerly on declaration, so the view traps the moment the container builds it — on iPad \
            that is when the window is resized wide enough for the sidebar. This is #950.
            """)
    }

    /// The sidebar footer specifically, pinned so the fix cannot be partially reverted.
    ///
    /// `appState` is the one that trapped; the other two matter for reasons that do not announce
    /// themselves. `\.modelContext` backs two `@Query`s that would have failed for the same reason
    /// the instant the first failure stopped masking them. `\.sceneID` has a default, so it would
    /// silently resolve to the wrong window rather than crash — the #752 hand-off failure mode.
    @Test("The sidebar footer re-injects all three values it depends on")
    func sidebarFooterInjectsAllThree() throws {
        let text = Self.stripped(try String(
            contentsOf: Self.appRoot.appending(path: "App/MainTabView.swift"), encoding: .utf8))
        let hit = try #require(text.range(of: ".tabViewSidebarFooter"))
        let body = Self.closureBody(after: hit.upperBound, in: text)

        #expect(body.contains(".environment(appState)"), "the crash itself: AppState is not injected")
        #expect(body.contains(".environment(\\.modelContext"), """
            `\\.modelContext` is not injected, so SidebarShortcuts' two @Query properties have no \
            context. They fail for the same reason AppState did.
            """)
        #expect(body.contains(".environment(\\.sceneID"), """
            `\\.sceneID` is not injected. It has a default value, so this does not crash — it \
            silently addresses the footer's hand-off to the wrong window when a second iPad scene \
            is open.
            """)
    }
}
