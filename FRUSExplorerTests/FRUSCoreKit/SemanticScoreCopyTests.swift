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
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - SemanticScoreCopyTests

/// The score's percentage and the words a row's accessibility value says (#1577 lane 3).
///
/// Version history:
///   1.0 — #1577 lane 3: initial implementation
///   1.1 — 2026-11-24: FRUS Explorer Light's S27a — moved here from `UITestMeaningSeederTests.swift` with
///         ``SemanticScoreCopy``, which is FRUSCoreKit's, and its chip's words; the views' wiring is the app's
@Suite("The semantic score, as a percentage and in words")
struct SemanticScoreCopyTests {

    @Test("The percentage is the score clamped to 0…1 and rounded")
    func percent() {
        #expect(SemanticScoreCopy.percent(for: 1) == 100)
        #expect(SemanticScoreCopy.percent(for: 0.6484375) == 65)
        #expect(SemanticScoreCopy.percent(for: 0.609375) == 61)
        #expect(SemanticScoreCopy.percent(for: 0.004) == 0)
        #expect(SemanticScoreCopy.percent(for: 0.005) == 1)
        #expect(SemanticScoreCopy.percent(for: -0.3) == 0)
        #expect(SemanticScoreCopy.percent(for: 1.2) == 100)
    }

    @Test("The accessibility value says the chip's figure in words")
    func accessibilityValue() {
        #expect(SemanticScoreCopy.accessibilityValue(for: 0.6484375) == "Semantic match 65 percent")
        #expect(SemanticScoreCopy.accessibilityValue(for: 1) == "Semantic match 100 percent")
        #expect(SemanticScoreCopy.accessibilityValue(for: -1) == "Semantic match 0 percent")
    }

    @Test("The chip's words give the figure the accessibility value says")
    func chipLabel() {
        #expect(SemanticScoreCopy.chipLabel(for: 0.6484375) == "Semantic match · 65%")
        for score in [0.6484375, 0.609375, 0.005, -0.3, 1.2] {
            #expect(SemanticScoreCopy.chipLabel(for: score) == "Semantic match · \(SemanticScoreCopy.percent(for: score))%",
                    "the chip no longer draws the figure the accessibility value says")
        }
    }

    #if !SWIFT_PACKAGE
    // It reads the app's views.
    @Test("The iPhone's result row gives its score as its accessibility value, and the chip draws the same figure")
    func theRowSaysItsScore() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let view = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Search/SearchView.swift"), encoding: .utf8)
        let squeezed = view.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined().filter { !$0.isWhitespace }
        // Since #1684 the label is the row as drawn, not the heading alone; the value still follows it.
        #expect(squeezed.contains(
            ".accessibilityLabel(SearchResultAccessibility.label(for:result,tags:chips))"
            + ".accessibilityValue(result.semanticScore.map(SemanticScoreCopy.accessibilityValue(for:))??\"\")"),
                "the row's value does not follow its label, or is not the score's words")
        let chip = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Search/SemanticSearchSharedViews.swift"),
                              encoding: .utf8)
        // Since FRUS Explorer Light's S27a the chip draws FRUSCoreKit's words for the score, whose figure is the one the
        // accessibility value says.
        #expect(chip.contains("Text(SemanticScoreCopy.chipLabel(for: score))"),
                "the chip no longer draws the score's words")
    }
    #endif
}
