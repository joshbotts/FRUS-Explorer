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
/// A collection's export options live in **three** parallel implementations:
///
/// - `CollectionEditorView.frontMatterRows` — the iPhone drill-in, the iPad ⚙ sheet, and the
///   macOS **Edit Collection** sheet.
/// - `MacCollectionManagerView.macCollectionSettingsForm` — the macOS **Collections window**
///   (⌘⇧K), which is the surface a Mac user actually reaches.
/// - `CollectionAttributesRows` — the iOS/iPad **document inspector**'s Collection section.
///   (macOS suppresses it there deliberately, passing `showsCollectionSettings: false`, because
///   the ⚙ popover owns those settings on that platform.)
///
/// #617 added `includeMethodAppendix` to the first only. #620 caught the second — the owner went
/// looking for the control to seed the CloudKit schema and could not find it. **The first version
/// of this suite then asserted parity over those two files and passed, while the third was still
/// missing it**, which is the lesson: a parity test is only as good as its list of surfaces, so
/// `listCoversTheModel` below now guards the surface list from the model side.
///
/// That is the same shape as `project_dual_settings_views` (iOS `SettingsView` vs macOS
/// `FRUSSettingsView`) and as #606/#616 (an iOS-only working-corpus banner). A source audit is the
/// cheap mechanical answer: no runtime test can reach a macOS `Form` from an iOS test bundle, but
/// both files can be read.
///
/// ## What is pinned, and what is deliberately not
/// Pinned: for each toggle, that **every** surface binds it, and that each writes it back from its own control.
/// Not pinned: layout, ordering, or wording beyond the localized key — those are design choices
/// that should be free to differ per platform. The invariant is *reachability*, not sameness.
///
/// Version history:
///   1.0 — M-2 follow-up: initial implementation, after #617 shipped a Mac-unreachable toggle
///   1.1 — #1415: the write-back check also accepts a toggle committed from its own binding, which is how
///         `CollectionEditorView` writes its toggles from #1415 on
///   1.2 — #1415 review, round 1: the write-back check reads code only, so a comment quoting either shape cannot
///         satisfy it
///   1.3 — MACCOL: the inspector's copy (`CollectionAttributesRows`) binds each toggle through `saving(\.x)`, which
///         writes the model and saves each switch, instead of `$collection.x`, which left the save to autosave
///   1.4 — MACCOL review, round 1: the write-back check accepts only the per-control commit. The Mac window's
///         `saveMetadata()` was the last surface to copy its mirrors onto the model (`collection.x = x`), all seven fields
///         on every edit, and MACCOL removed it; the docs no longer describe it as current
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

    /// The files that must each offer every toggle, and how each binds its controls.
    ///
    /// Two binding styles are in use and both are legitimate, so the assertions below branch on
    /// this rather than demanding one shape. A `@State` mirror (`true`: the iOS editor and the Mac
    /// window) must be seeded from the model and committed from its own control; the inspector's
    /// copy binds the model itself through `saving(\.x)`, which writes and saves, so it needs
    /// neither, and asking it for a mirror's seed would be asserting a bug.
    private static let surfaces: [(path: String, mirrorsState: Bool)] = [
        ("FRUSExplorer/Collections/CollectionEditorView.swift", true),
        ("FRUSExplorer/Collections/MacCollectionManagerView.swift", true),
        ("FRUSExplorer/Collections/CollectionCompositionRows.swift", false)
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
        for (path, _) in Self.surfaces {
            let text = try Self.source(path)
            for toggle in Self.toggles {
                // A bound control, not merely a mention: `isOn: $includeColophon` on a state-mirroring
                // surface, or `isOn: saving(\.includeColophon)` on the directly bound one (`$collection.x`
                // before MACCOL). A doc comment naming the property would otherwise satisfy a bare
                // substring search — which is exactly how a missing control could keep passing.
                #expect(text.contains("$\(toggle)") || text.contains("$collection.\(toggle)")
                            || text.contains("saving(\\.\(toggle))"),
                        """
                        \(path) has no control bound to `\(toggle)`. Every per-collection export \
                        option must be reachable on every platform; #617 shipped one that was not, \
                        and the macOS Collections window had no way to set it.
                        """)
            }
        }
    }

    /// A control that never writes back is worse than no control: it moves, and nothing happens.
    ///
    /// One write-back shape is legitimate: each change committed from the control's OWN binding,
    /// `committing($x) { CollectionEditorCommit.flag($0, to: \.x, of: collection) }`, which writes that one field. The
    /// iOS editor took it at #1415, because on the iPhone its settings screen covers the editor and a covered, pushed
    /// editor runs none of the `onChange` a save would hang from; the Mac window took it at MACCOL. The Mac window had
    /// copied its mirror onto the model in `saveMetadata()` (`collection.x = x`) — all seven fields, from copies that
    /// were stale whenever another writer had changed one — and this check accepted that shape until MACCOL removed it.
    /// The shape is matched as that whole call, whitespace collapsed, in CODE: every line that is a `//` or `///` comment
    /// is blanked first, so a comment quoting it — a doc comment describing the call, say — cannot stand in for a
    /// control that makes it. (A `/* */` block comment is not stripped; neither surface has one.)
    @Test("Every toggle is written back to the model on every state-mirroring surface")
    func everyToggleIsPersisted() throws {
        for (path, mirrorsState) in Self.surfaces where mirrorsState {
            let text = try Self.source(path)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? "" : String($0) }
                .joined(separator: "\n")
            let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            for toggle in Self.toggles {
                let committed = collapsed.contains(
                    "committing($\(toggle)) { CollectionEditorCommit.flag($0, to: \\.\(toggle), of: collection) }")
                #expect(committed, "\(path) binds `\(toggle)` but does not commit it from its own control")
            }
        }
    }

    /// A directly-bound surface must bind the MODEL, not a local copy — and, since MACCOL, save each switch as it is
    /// made: `saving(\.x)`, whose setter writes `collection[keyPath:]` and saves, not `$x` (a stray `@State` there would
    /// edit a value nothing ever reads back) and not `$collection.x` (which writes the model and leaves the save to
    /// autosave, so a foreground kill could lose the switch). `SectionDefaultsSaveTests` switches each toggle in the
    /// hosted rows; this pins that every toggle goes through the saving binding.
    @Test("Directly-bound surfaces bind the model itself, and save each switch")
    func directSurfacesBindTheModel() throws {
        for (path, mirrorsState) in Self.surfaces where !mirrorsState {
            let text = try Self.source(path)
            for toggle in Self.toggles {
                #expect(text.contains("saving(\\.\(toggle))"),
                        "\(path) must bind `\(toggle)` through `saving(\\.\(toggle))`, which writes the model and saves")
            }
            let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            #expect(collapsed.contains("set: { collection[keyPath: keyPath] = $0; save() }"),
                    "\(path)'s saving(_:) does not write the collection and save in its setter")
        }
    }

    /// And seeded from the model when the surface opens, or the control shows `false` for a
    /// collection that has the option on. (Until MACCOL the Mac window's first edit to any other
    /// field then wrote that `false` back; each control now commits only itself, so a wrong seed
    /// misleads without writing.)
    @Test("Every toggle is seeded from the model on every state-mirroring surface")
    func everyToggleIsSeeded() throws {
        for (path, mirrorsState) in Self.surfaces where mirrorsState {
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
