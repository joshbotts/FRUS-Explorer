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

// MARK: - ArchivalCopyRulesTests

/// The copy rules for strings derived from the design handoff (#838).
///
/// The archival surfaces were drawn before they were written, and the mocks carry four
/// conventions that are correct *in a design file* and wrong in a shipped string: the ●/○
/// measured-versus-illustrative marks, GitHub issue numbers, artboard ids, and British
/// spellings. Each of the four appears in copy the handoff itself calls final, so "remember not
/// to" is not a control — three of the four would read as ordinary prose to a reviewer who had
/// not seen the mocks.
///
/// This suite is that control. It reads the shipped sources rather than a copy of the strings,
/// so a new violation fails on the commit that introduces it.
///
/// Version history:
///   1.0 — Session 2026-08-11: #838
@Suite("Archival copy rules (#838)")
struct ArchivalCopyRulesTests {

    /// The files whose user-facing strings came out of the design handoff.
    private static let sources = [
        "Analytics/ArchivalAnalyticsView.swift",
        "Analytics/ArchivalNetworkView.swift",
        "Analytics/ArchivalFlowsView.swift",
        "Analytics/ArchivalAllUnitsSheet.swift",
        "Analytics/ArchivalAnalyticsExport.swift",
        "Analytics/ArchivalAnalyticsAxes.swift",
        // The scans header lives here, not in the archival family — and the copy rule is about
        // artboard-derived strings wherever they ship.
        "SourceExplorer/SourceExplorerView.swift",
        "SourceExplorer/MacSourceExplorerView.swift",
    ]

    private static func source(_ relative: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/\(relative)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Every `defaultValue:` literal in a file — the text a reader actually sees.
    ///
    /// Scanning the whole file would flag the design notes in the doc comments, which is exactly
    /// where this vocabulary *should* live: the comments explain why a mock said something, and
    /// forbidding it there would delete the reasoning along with the defect.
    private static func shippedStrings(in source: String) -> [String] {
        var results: [String] = []
        var rest = Substring(source)
        while let marker = rest.range(of: "defaultValue: \"") {
            rest = rest[marker.upperBound...]
            var literal = ""
            var escaped = false
            for character in rest {
                if escaped { literal.append(character); escaped = false; continue }
                if character == "\\" { escaped = true; continue }
                if character == "\"" { break }
                literal.append(character)
            }
            results.append(literal)
        }
        return results
    }

    @Test("No measured/illustrative marks reach a shipped string")
    func noProvenanceGlyphs() throws {
        // ● and ○ are the handoff's own number convention and are drawn INSIDE UI labels on
        // every artboard — "241 · 3.0% ○", "463 ●", even inside the packet PDF pages. They mean
        // nothing to a reader.
        for relative in Self.sources {
            for text in Self.shippedStrings(in: try Self.source(relative)) {
                #expect(!text.contains("●") && !text.contains("○"), """
                    \(relative) ships "\(text.prefix(60))…", which carries the handoff's \
                    measured/illustrative mark.
                    """)
            }
        }
    }

    @Test("No issue numbers or artboard ids reach a shipped string")
    func noTrackerReferences() throws {
        // The handoff writes "(#828)" and "(#808)" into captions it marks copy-final, and
        // artboard ids like "(1j)" into list footers. Both are conversation between the design
        // and the tracker, not something a researcher can act on.
        let issue = try Regex(#"\(#\d{2,4}\)"#)
        let artboard = try Regex(#"\(1[a-k]\)"#)
        for relative in Self.sources {
            for text in Self.shippedStrings(in: try Self.source(relative)) {
                #expect(text.firstMatch(of: issue) == nil,
                        "\(relative) ships an issue number: \(text.prefix(80))")
                #expect(text.firstMatch(of: artboard) == nil,
                        "\(relative) ships an artboard id: \(text.prefix(80))")
            }
        }
    }

    @Test("Shipped strings use en-US spellings")
    func enUSSpellings() throws {
        // The app localizes en-US. `Coloured`, `recognises` and `digitised` all appear in
        // handoff copy marked final — and `Coloured` is in the README's own caption text, so it
        // would be copied verbatim by anyone working from the document rather than the mock.
        // Lower-case entries matched CASE-INSENSITIVELY below, rather than a hand-kept list of
        // pairs. The list HAD capitalised variants for some words and not others — "Coloured"
        // and "Neighbours" but only a lower-case "digitised" — so four shipped
        // `defaultValue: "Digitised Scans"` strings walked past it, and adding the files that
        // hold them to `sources` would STILL have left the suite green. A guard whose coverage
        // depends on which capitalisations someone remembered is not a guard.
        let banned = ["coloured", "recognises", "recognise", "digitised", "digitise",
                      "organise", "organised", "neighbours", "behaviour", "centre",
                      "colour"]
        for relative in Self.sources {
            for text in Self.shippedStrings(in: try Self.source(relative)) {
                let lowered = text.lowercased()
                for word in banned {
                    #expect(!lowered.contains(word), """
                        \(relative) ships "\(word)" in: \(text.prefix(80))
                        """)
                }
            }
        }
    }

    @Test("The relabel reached every control, and no surface still says the old words")
    func controlsUsePlainLabels() throws {
        let view = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        let shipped = Self.shippedStrings(in: view)
        #expect(shipped.contains("Show"), "the unit control's caption")
        #expect(shipped.contains("Count by"), "the weight control's caption")
        #expect(shipped.contains("Era"), "the band control's caption")
        // The old captions were the terms of art. They may still appear in explanatory prose —
        // that is the point of moving them into the popover — but not as a control's label.
        #expect(!shipped.contains("Units"))
        #expect(!shipped.contains("Weight"))
        // Scoped to the CONTROL's own key. "Coverage era" survives as a chart axis name under
        // `archival.library.bands.axis`, which is correct and must not be swept up: an axis
        // names a dimension, a chip names a thing the reader changes.
        for key in ["archival.filter.era", "archival.filter.units", "archival.filter.weight"] {
            let pattern = "\"" + key + "\", defaultValue: \"Coverage era\""
            #expect(!view.contains(pattern), "\(key) still carries the old term of art")
        }
        #expect(view.contains("\"archival.filter.era\", defaultValue: \"Era\""))
        #expect(view.contains("\"archival.library.bands.axis\","), """
            The Your Library axis must keep its OWN key: one key carrying two default values \
            means translating either silently rewrites the other.
            """)
    }

    @Test("The page keeps the disclosures that change with the controls")
    func conditionalCaveatsStayOnThePage() throws {
        // The ⓘ consolidation moved the standing method statement into the popover. The
        // conditional disclosures had to stay: they describe the chart on screen right now, and
        // a reader who never opens a popover must still be told that the largest bar is missing.
        let view = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(view.contains("collectionsConditionalCaveats("))
        #expect(view.contains("archival.caveats.umbrella"),
                "what the umbrella filter withheld is a property of THIS view and stays on it")
        #expect(view.contains("archival.caveats.noUsageIndex"),
                "a failed artifact load must be said on the page, not hidden behind a button")
        #expect(view.contains("archival.caveats.pointer"),
                "the page must point at where the method statement went")
        // And the popover must actually have absorbed it.
        let theme = try Self.source("../FRUSExplorer/Theme/FRUSTheme.swift")
        #expect(theme.contains("archival.info.method.detail"))
        #expect(theme.contains("not read from an archive's catalog"), """
            The parsed-not-catalogued claim is the load-bearing sentence of the whole surface. \
            Removing it from the page without it landing in the popover would delete it.
            """)
    }
}
