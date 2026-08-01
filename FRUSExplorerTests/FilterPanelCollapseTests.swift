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

// MARK: - FilterPanelCollapseTests

/// The Advanced Filters panel's collapsible groups, and the ordering that goes with them.
///
/// ## What collapsing is allowed to hide
/// Nothing the user must act on. Two of these sections carry a **refusal**: applying a custom
/// scope or a subject facet whose volumes are not indexed warns instead of silently returning
/// nothing, and `SearchFilterView` already fixed one round of that warning being unreachable. A
/// disclosure that could swallow it would reintroduce exactly that bug, so the group opens itself
/// and cannot be shut while the warning stands.
///
/// These are source audits. The panel is a SwiftUI `Form` with `@State` disclosure bindings that
/// no unit test can drive, and the alternative — no check at all — is how the ordering and the
/// warning coupling would drift apart in the two hand-maintained platform bodies.
///
/// Version history:
///   1.0 — filter-panel collapse: initial implementation
@Suite("Filter panel collapse and ordering")
struct FilterPanelCollapseTests {

    private static func source() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(
            contentsOf: root.appending(path: "FRUSExplorer/Search/SearchFilterView.swift"),
            encoding: .utf8)
        #expect(text.count > 1_000, "SearchFilterView.swift is implausibly small — did it move?")
        return text
    }

    /// The section order in one platform body, as a list of section-property names.
    private static func order(in body: String, from source: String) throws -> [String] {
        let start = try #require(source.range(of: body))
        let end = try #require(source.range(of: "}", range: source.range(of: "resultPreviewSection",
                                                                        range: start.upperBound..<source.endIndex)!.upperBound..<source.endIndex))
        let slice = source[start.upperBound..<end.lowerBound]
        var names: [String] = []
        for line in slice.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//") else { continue }
            for name in ["projectScopeSection", "dateRangeSection", "workingCorpusSection",
                         "customScopeSection", "subjectFacetSection", "volumeScopeSectionMac",
                         "volumeScopeSectioniOS", "personSection", "documentTypeSection",
                         "userTagsSection", "scopeSection", "resultPreviewSection"]
                where trimmed.contains(name) && !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }

    // MARK: - Which groups collapse

    /// A closed set on purpose: collapsing a one-row section costs a click and saves nothing.
    @Test("Exactly the four unbounded groups collapse")
    func onlyTheRightGroupsCollapse() throws {
        let text = try Self.source()
        for group in ["case workingCorpus, customScope, subjectFacet, userTags"] {
            #expect(text.contains(group), "the collapsible set changed — is that deliberate?")
        }
        for section in ["workingCorpusSection", "customScopeSection", "subjectFacetSection",
                        "userTagsSection"] {
            let range = try #require(text.range(of: "private var \(section)"))
            let body = text[range.upperBound...].prefix(1_400)
            #expect(body.contains("collapsibleSection("), "\(section) is not collapsible")
        }
        // And the cheap ones are NOT wrapped — a collapsed one-row section is pure friction.
        for section in ["dateRangeSection", "documentTypeSection", "personSection"] {
            let range = try #require(text.range(of: "private var \(section)"))
            let body = text[range.upperBound...].prefix(900)
            #expect(!body.contains("collapsibleSection("),
                    "\(section) is cheap and should stay open")
        }
    }

    // MARK: - What a collapsed group must not swallow

    /// `customScopeSection` is `scopeWarningName`'s primary host. A refusal inside a shut group is
    /// the same defect as no refusal.
    @Test("A scope refusal forces its group open")
    func scopeRefusalForcesOpen() throws {
        let text = try Self.source()
        let range = try #require(text.range(of: "private var customScopeSection"))
        let body = text[range.upperBound...].prefix(1_400)
        #expect(body.contains("forced: scopeWarningName != nil"))
    }

    /// And the fallback host, which renders the warning precisely when the primary one does not
    /// exist — so its force condition has to carry the same `customScopes.isEmpty` guard.
    @Test("The facet fallback forces open under the same condition it renders under")
    func facetFallbackForcesOpen() throws {
        let text = try Self.source()
        let range = try #require(text.range(of: "private var subjectFacetSection"))
        // A generous window: this section's footer alone is ~250 characters of prose.
        let body = text[range.upperBound...].prefix(2_600)
        #expect(body.contains("forced: customScopes.isEmpty && scopeWarningName != nil"))
        #expect(body.contains("if customScopes.isEmpty, let warning = scopeWarningName"),
                "the render condition moved; the force condition must move with it")
    }

    /// `workingCorpusRow`'s own comment says this is the moment the truncation has to be legible.
    /// Collapsing may not defer that: the group opens itself when coverage is partial, and the
    /// collapsed label carries the capture provenance regardless.
    @Test("Partial coverage forces the corpus group open, and the summary carries provenance")
    func corpusCoverageForcesOpen() throws {
        let text = try Self.source()
        let range = try #require(text.range(of: "private var workingCorpusSection"))
        let body = text[range.upperBound...].prefix(1_400)
        #expect(body.contains("forced: workingCorpusNeedsAttention"))
        #expect(body.contains("summary: workingCorpusSummary"))

        // The force rule covers both a refusal and an incompletely-reachable applied corpus.
        let rule = try #require(text.range(of: "private var workingCorpusNeedsAttention"))
        let ruleBody = text[rule.upperBound...].prefix(600)
        #expect(ruleBody.contains("corpusWarningName != nil"))
        #expect(ruleBody.contains("!resolution.isComplete"))

        // And the collapsed label states what the set IS, not just how many there are.
        let summary = try #require(text.range(of: "private var workingCorpusSummary"))
        #expect(text[summary.upperBound...].prefix(700).contains("sourceDescription"),
                "a collapsed corpus group that hides the truncation is the bug this replaces")
    }

    /// Every collapsible section keeps its explanatory footer — the prose that says what the
    /// group is for sits outside the disclosure, so it reads whether open or shut.
    @Test("Collapsing does not take the footers with it")
    func footersSurvive() throws {
        let text = try Self.source()
        for footer in ["search.scope.custom.footer", "search.corpus.footer",
                       "search.subject.facet.footer"] {
            #expect(text.contains(footer), "\(footer) was lost in the conversion")
        }
    }

    // MARK: - Ordering, on both bodies

    @Test("Working corpora sit above volume scopes, and person above document type")
    func orderingSwaps() throws {
        let text = try Self.source()
        for body in ["private var macBody", "private var iOSBody"] {
            let order = try Self.order(in: body, from: text)
            let corpus = try #require(order.firstIndex(of: "workingCorpusSection"))
            let custom = try #require(order.firstIndex(of: "customScopeSection"))
            let person = try #require(order.firstIndex(of: "personSection"))
            let type = try #require(order.firstIndex(of: "documentTypeSection"))
            #expect(corpus < custom, "\(body): working corpora must precede volume scopes")
            #expect(person < type, "\(body): person holds the only TextField and must sit higher")
        }
    }

    /// The two bodies are hand-maintained forty lines apart and nothing else pins them together.
    /// Accidental divergence here is the standing hazard in this file.
    @Test("Both platform bodies order their shared sections identically")
    func bothBodiesAgree() throws {
        let text = try Self.source()
        let mac = try Self.order(in: "private var macBody", from: text)
            .filter { $0 != "volumeScopeSectionMac" }
        let iOS = try Self.order(in: "private var iOSBody", from: text)
            .filter { $0 != "volumeScopeSectioniOS" }
        #expect(mac == iOS,
                """
                The platform bodies diverged.
                macOS: \(mac)
                iOS:   \(iOS)
                Intentional divergence is defensible — update this test and say why. Accidental \
                divergence is the bug this catches.
                """)
    }
}
