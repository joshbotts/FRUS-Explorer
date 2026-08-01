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
@testable import FRUSExplorer

// MARK: - CollectionExportToggleParityTests

/// Every per-collection export toggle must be reachable on **every** platform.
///
/// ## The bug this exists to stop happening a fourth time
/// A collection's export options live in two parallel implementations:
///
/// - `CollectionEditorView.frontMatterRows` — the iPhone drill-in, the iPad ⚙ sheet, and the
///   macOS **Edit Collection** sheet.
/// - `MacCollectionManagerView.macCollectionSettingsForm` — the macOS **Collections window**
///   (⌘⇧K), which is the surface a Mac user actually reaches.
///
/// #617 added `includeMethodAppendix` to the first and not the second, so on the Mac the setting
/// existed, synced, and drove the exporters — with no control anywhere in the window the owner
/// uses. It was found by the owner going looking for it, which is the expensive way.
///
/// That is the same shape as `project_dual_settings_views` (iOS `SettingsView` vs macOS
/// `FRUSSettingsView`) and as #606/#616 (an iOS-only working-corpus banner). A source audit is the
/// cheap mechanical answer: no runtime test can reach a macOS `Form` from an iOS test bundle, but
/// both files can be read.
///
/// ## What is pinned, and what is deliberately not
/// Pinned: for each toggle, that **both** files bind it, and that both write it back on save.
/// Not pinned: layout, ordering, or wording beyond the localized key — those are design choices
/// that should be free to differ per platform. The invariant is *reachability*, not sameness.
///
/// Version history:
///   1.0 — M-2 follow-up: initial implementation, after #617 shipped a Mac-unreachable toggle
@Suite("Collection export toggle parity")
struct CollectionExportToggleParityTests {

    /// The per-collection export toggles, by stored property name.
    ///
    /// Adding a stored `Bool` export option to `Collection` means adding it here. The suite then
    /// tells you every place it has to be wired, instead of a user telling you months later.
    private static let toggles = [
        "includeColophon",
        "includeProjectProvenance",
        "includeMethodAppendix"
    ]

    /// The two files that must each offer every toggle.
    private static let surfaces = [
        "FRUSExplorer/Collections/CollectionEditorView.swift",
        "FRUSExplorer/Collections/MacCollectionManagerView.swift"
    ]

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, "\(path) is implausibly small — did it move?")
        return text
    }

    @Test("Every export toggle has a control on every collection-settings surface")
    func everyToggleIsReachable() throws {
        for path in Self.surfaces {
            let text = try Self.source(path)
            for toggle in Self.toggles {
                // A `$`-bound control, not merely a mention: `isOn: $includeColophon` or
                // `Toggle(isOn: $includeMethodAppendix)`. A doc comment naming the property would
                // otherwise satisfy a bare substring search — which is exactly how a missing
                // control could keep passing.
                #expect(text.contains("$\(toggle)"),
                        """
                        \(path) has no control bound to `\(toggle)`. Every per-collection export \
                        option must be reachable on every platform; #617 shipped one that was not, \
                        and the macOS Collections window had no way to set it.
                        """)
            }
        }
    }

    /// A control that never writes back is worse than no control: it moves, and nothing happens.
    @Test("Every toggle is written back to the model on both surfaces")
    func everyToggleIsPersisted() throws {
        for path in Self.surfaces {
            let text = try Self.source(path)
            for toggle in Self.toggles {
                #expect(text.contains("collection.\(toggle) = \(toggle)"),
                        "\(path) binds `\(toggle)` but never saves it")
            }
        }
    }

    /// And seeded from the model when the surface opens, or the control shows `false` for a
    /// collection that has the option on — and the first edit to any other field silently turns it
    /// off again.
    @Test("Every toggle is seeded from the model on both surfaces")
    func everyToggleIsSeeded() throws {
        for path in Self.surfaces {
            let text = try Self.source(path)
            for toggle in Self.toggles {
                #expect(text.contains("State(initialValue: collection.\(toggle))")
                        || text.contains("State(initialValue: c.\(toggle))"),
                        "\(path) never seeds `\(toggle)` from the stored collection")
            }
        }
    }

    /// The toggle list above is only as good as its coverage of the model. This catches a fourth
    /// export `Bool` being added to `Collection` and never entered here — in which case the three
    /// tests above would keep passing while saying nothing about it.
    @Test("The toggle list covers every export Bool on the model")
    func listCoversTheModel() throws {
        let model = try Self.source("FRUSExplorer/Models/Collection.swift")
        var found: [String] = []
        for line in model.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("var include"), trimmed.contains(": Bool = ") else { continue }
            let name = trimmed.dropFirst("var ".count).prefix { $0 != ":" }
            found.append(String(name))
        }
        // `includeFootnotes` / `includeNotes` / `includeSourceNote` / `includeWordCloud` are
        // composition defaults rendered by `CollectionCompositionRows`, which BOTH surfaces embed
        // as one shared view — so they cannot diverge and are not this suite's business.
        let composition: Set<String> = ["includeFootnotes", "includeNotes", "includeSourceNote",
                                        "includeWordCloud"]
        let expected = Set(found).subtracting(composition)
        #expect(expected == Set(Self.toggles),
                """
                Collection's export Bools are \(expected.sorted()) but this suite checks \
                \(Self.toggles.sorted()). Add the new one to `toggles` — and to BOTH surfaces.
                """)
    }
}
