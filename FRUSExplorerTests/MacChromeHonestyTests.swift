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

/// Two macOS chrome defects from the UI review, both fixable and testable without a Mac
/// (UI review M-10 and M-8).
///
/// Version history:
///   1.0 — CW-10b
@Suite("Mac chrome honesty")
struct MacChromeHonestyTests {

    // MARK: - M-10 · the search-scope chip wired to nothing

    /// The repository root, found by walking up from this file.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Reads a source file under the app target.
    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// One property's declaration, ending where the next property at the same indent begins.
    ///
    /// **A fixed-length window does not work here, and mutation testing is what proved it.** The
    /// first version of this helper took 400 characters from the declaration; re-introducing the
    /// dead `scopeCollections` immediately above `scopeNotes` put *that* property's `didSet`
    /// inside the window, so the test passed with the defect restored. It looked like coverage
    /// and was measuring the wrong property.
    ///
    /// - Parameters:
    ///   - property: The property name.
    ///   - source: The view model's source.
    /// - Returns: The declaration text, or `""` when the property is absent.
    private static func declarationBody(of property: String, in source: String) -> String {
        guard let start = source.range(of: "var \(property): Bool") else { return "" }
        let rest = source[start.upperBound...]
        // The next stored property at type scope. Everything before it belongs to this one.
        guard let next = rest.range(of: "\n    var ") else { return String(rest) }
        return String(rest[..<next.lowerBound])
    }

    /// Every scope the Mac search chrome offers must reach the query.
    ///
    /// **This is the invariant, not "the Collections chip is gone".** The defect was a control
    /// whose stored property nothing read: `scopeCollections` had no `didSet`, no projection into
    /// `parameters`, and exactly one reader in the codebase — the chip's own binding. So the test
    /// asserts the *rule* — that each `ScopeChip` in the scope row binds to a property the view
    /// model actually forwards — which a re-added Collections chip would also have to satisfy.
    @Test("every scope chip binds to a scope the view model forwards")
    func everyScopeChipIsWired() throws {
        let sheet = try Self.source("FRUSExplorer/App/SearchSheet.swift")
        let viewModel = try Self.source("FRUSExplorer/App/MacSearchViewModel.swift")

        // The properties each `ScopeChip(...)` in the scope row binds to.
        var bound: [String] = []
        for line in sheet.components(separatedBy: .newlines) where line.contains("ScopeChip(") {
            guard let range = line.range(of: "isOn: $searchVM.") else { continue }
            let tail = line[range.upperBound...]
            let name = tail.prefix { $0.isLetter || $0.isNumber }
            if !name.isEmpty { bound.append(String(name)) }
        }

        // Guard against a vacuous pass: if the parse finds nothing, every assertion below is
        // trivially true and the suite would go green having measured nothing.
        #expect(bound.count >= 3, "expected the scope chips, parsed \(bound)")

        for property in bound {
            // A forwarded scope declares a `didSet`. The dead one was `var x: Bool = false` with
            // a trailing comment and nothing else.
            #expect(viewModel.contains("var \(property): Bool") ,
                    "\(property) is bound by a ScopeChip but is not declared on MacSearchViewModel")
            let declaration = Self.declarationBody(of: property, in: viewModel)
            #expect(declaration.contains("didSet"),
                    "The '\(property)' scope chip is a live control bound to a property that nothing reads — toggling it cannot change the results. Wire it through `parameters`, disable it with a visible reason, or remove the chip (M-10).")
        }
    }

    // MARK: - M-8 · the toolbar centre

    @Test("a resolved volume and document number name the location")
    func principalNamesLocation() {
        #expect(MacDocumentTitle.principalLabel(volumeLabel: "Soviet Union · 1969-76 v20",
                                                documentNumber: "475",
                                                documentId: "frus1969-76v20/d475")
                == "Soviet Union · 1969-76 v20 · Doc 475")
    }

    @Test("a document with no number still names its volume")
    func noDocumentNumber() {
        // Editorial notes and front-matter sections carry no document number; the volume is
        // still the orientation this strip exists to give.
        #expect(MacDocumentTitle.principalLabel(volumeLabel: "1969-76 v20",
                                                documentNumber: nil,
                                                documentId: "frus1969-76v20/comp1")
                == "1969-76 v20")
        #expect(MacDocumentTitle.principalLabel(volumeLabel: "1969-76 v20",
                                                documentNumber: "",
                                                documentId: "frus1969-76v20/comp1")
                == "1969-76 v20")
    }

    @Test("an unknown volume falls back to the id rather than inventing one")
    func unknownVolumeFallsBack() {
        // A window restored for a volume no longer in the manifest. The id is what this strip
        // showed before M-8, so the degraded state keeps the old behaviour.
        #expect(MacDocumentTitle.principalLabel(volumeLabel: nil,
                                                documentNumber: "475",
                                                documentId: "frus1946v06/d475")
                == "frus1946v06/d475")
        #expect(MacDocumentTitle.principalLabel(volumeLabel: "",
                                                documentNumber: "475",
                                                documentId: "frus1946v06/d475")
                == "frus1946v06/d475")
    }

    @Test("the fallback is what keeps the monospaced face")
    func fallbackDrivesTypeface() {
        // The view branches on this: an id stays monospaced, prose does not. A monospaced
        // "Soviet Union · 1969-76 v20 · Doc 475" reads as machine output, which is half of what
        // M-8 objects to in the first place.
        #expect(MacDocumentTitle.isFallback(volumeLabel: nil))
        #expect(MacDocumentTitle.isFallback(volumeLabel: ""))
        #expect(!MacDocumentTitle.isFallback(volumeLabel: "1969-76 v20"))
    }

    @Test("the strip never carries the volume-title boilerplate")
    func noBoilerplate() {
        // The regression guarded: passing `entry.title` instead of the distilled form would fill
        // the window's most valuable strip with "Foreign Relations of the United States, …" —
        // the exact problem #237 built the iOS two-line title to see past.
        let distilled = ChronologyViewModel.distilledVolumeLabel(
            volumeId: "frus1946v06",
            subseries: "1946",
            title: "Foreign Relations of the United States, 1946, Volume VI, Eastern Europe")
        let label = MacDocumentTitle.principalLabel(volumeLabel: distilled,
                                                   documentNumber: "475",
                                                   documentId: "frus1946v06/d475")
        #expect(!label.contains("Foreign Relations"))
        #expect(label.contains("Doc 475"))
    }
}
