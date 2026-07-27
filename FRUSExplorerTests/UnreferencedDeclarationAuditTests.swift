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

/// Fails when a `private var` is declared and never used in its own file.
///
/// ## Why this exists
/// Swift emits **no warning** for an unreferenced private computed property, and this
/// project has now shipped that bug twice:
///
/// 1. `IndexingSetupWizardView.swift` declared the live `WhileIndexingSheet` under a
///    filename naming a type it did not contain, and was twice judged dead code (O-0).
/// 2. O-3 declared `indexingCloudBackdrop` in `MainTabView` and **never placed it in the
///    view hierarchy**. It compiled, it tested green, it shipped, and the word-cloud
///    backdrop rendered on no device. Found only because the owner went looking for it
///    on an iPad.
///
/// The second is the dangerous shape: a `@ViewBuilder private var` that is never
/// referenced is an entire piece of UI that silently does not exist. Nothing else in the
/// toolchain catches it — not the compiler, not the tests, not a build.
///
/// ## Scope, deliberately narrow
/// Only `private var` declarations, only within their own file, and a name is "used" if it
/// appears anywhere else in the file outside a line comment. That keeps false positives at
/// zero (measured: the four this test was written against were all genuinely dead) without
/// needing an allowlist. Names referenced from string literals, KVC, or `#Preview` blocks
/// still count as used, because the search is textual.
///
/// Version history:
///   1.0 — O-3 fix: initial implementation
@Suite("Coding standards — unreferenced private declarations")
struct UnreferencedDeclarationAuditTests {

    @Test("No `private var` is declared without being used in its own file")
    func noUnreferencedPrivateVars() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("FRUSExplorer")

        // A literal regex, so the capture group is statically typed.
        let declaration = /(?m)^[ \t]*(?:@ViewBuilder[ \t]*\n[ \t]*)?private[ \t]+var[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*:/
        var offenders: [String] = []
        var scanned = 0

        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        for file in files {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            scanned += 1
            // Strip line comments so a name mentioned only in prose is not counted as a use.
            let code = source.split(separator: "\n", omittingEmptySubsequences: false)
                .map { line -> String in
                    guard let slash = line.range(of: "//") else { return String(line) }
                    return String(line[line.startIndex..<slash.lowerBound])
                }
                .joined(separator: "\n")

            for match in code.matches(of: declaration) {
                let name = String(match.1)
                let uses = code.ranges(of: name).count
                if uses <= 1 {
                    offenders.append("\(file.lastPathComponent): private var \(name)")
                }
            }
        }

        #expect(scanned > 100, "audit scanned only \(scanned) files — the walk is broken, not the code")
        #expect(offenders.isEmpty, """
            Declared but never used in their own file:
              \(offenders.joined(separator: "\n  "))

            For a plain value this is dead code. For a `@ViewBuilder` it is worse: a piece
            of UI that compiles, tests green, ships, and renders nowhere. Either place it in
            the hierarchy or delete it.
            """)
    }
}
