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

/// The macOS Search window's filter token row (UI review M-4, design option 3a).
///
/// ## What is worth testing
/// Not that a token appears — that is a `compactMap`. What matters is the pair of claims the design
/// rests on, both of which are falsifiable:
///
/// 1. **"An absent token means the default."** That is what licenses removing the always-visible
///    Type chips, so it has to hold for every field including the two that had chips.
/// 2. **"No filters — all types, front matter included, everything indexed."** That sentence is
///    what licenses removing the chips *without losing honesty*, and it is a claim that can be
///    false: `SearchParameters` carries four narrowings no token represents.
///
/// Version history:
///   1.0 — M-4 / design option 3a
@Suite("Search filter tokens")
struct SearchFilterTokensTests {

    /// A parameter set with nothing narrowing it.
    private func defaults() -> SearchParameters {
        SearchParameters(keywords: "wristonization")
    }

    private let noLabels = SearchFilterTokens.Labels()

    // MARK: - Absence is the default

    @Test("nothing set means no tokens at all")
    func atRestHasNoTokens() {
        #expect(SearchFilterTokens.tokens(parameters: defaults(), labels: noLabels).isEmpty)
    }

    @Test("every field can be added when none is active")
    func everyFieldIsAddable() {
        let addable = SearchFilterTokens.addableFields(parameters: defaults(), labels: noLabels)
        #expect(addable.count == SearchFilterField.allCases.count)
    }

    @Test("the two fields that used to have permanent chips are absent at their defaults")
    func defaultsProduceNoToken() {
        var params = defaults()
        params.documentTypeFilter = .all
        params.includeFrontMatter = true

        #expect(SearchFilterTokens.value(for: .type, parameters: params, labels: noLabels) == nil,
                "Type shows a token at `.all` — then 'an absent token means the default' is false for the one field the design removed a permanent control for")
        #expect(SearchFilterTokens.value(for: .frontMatter, parameters: params, labels: noLabels) == nil,
                "front matter shows a token while included, which is its default")
    }

    @Test("each field away from its default produces exactly one token")
    func nonDefaultsProduceTokens() {
        var params = defaults()
        params.documentTypeFilter = .editorialNotesOnly
        params.includeFrontMatter = false

        let tokens = SearchFilterTokens.tokens(
            parameters: params,
            labels: SearchFilterTokens.Labels(date: "1961 – 1963", years: "1962",
                                              volume: "frus1961-63v06", person: "Rusk",
                                              tags: "To read"))
        #expect(tokens.count == 7, "expected all seven, got \(tokens.map(\.field.rawValue))")
        #expect(SearchFilterTokens.addableFields(parameters: params, labels:
            SearchFilterTokens.Labels(date: "1961 – 1963", years: "1962",
                                      volume: "frus1961-63v06", person: "Rusk",
                                      tags: "To read")).isEmpty,
                "+ Filter still offers a field that already has a token")
    }

    @Test("tokens keep a stable order as values change")
    func orderIsStable() {
        var params = defaults()
        params.documentTypeFilter = .documentsOnly
        let withDate = SearchFilterTokens.tokens(
            parameters: params, labels: SearchFilterTokens.Labels(date: "1961 – 1963"))
        // Date is declared before Type, so it leads regardless of which was set first. A row
        // ordered by "recently added" moves a token the reader is about to click.
        #expect(withDate.map(\.field) == [.date, .type])
    }

    // MARK: - The honesty claim

    @Test("the at-rest line states the default only when the default is true")
    func atRestCaptionIsHonestWhenNothingNarrows() {
        let caption = SearchFilterTokens.atRestCaption(parameters: defaults())
        #expect(caption.contains("everything indexed"))
    }

    @Test("a working corpus is not 'everything indexed'")
    func documentScopeContradictsTheCaption() {
        var params = defaults()
        params.documentIds = ["frus1961-63v06/d1", "frus1961-63v06/d2"]

        #expect(SearchFilterTokens.tokens(parameters: params, labels: noLabels).isEmpty,
                "precondition: no token represents a document scope — that is why the caption matters")
        let caption = SearchFilterTokens.atRestCaption(parameters: params)
        #expect(!caption.contains("everything indexed"), """
            The row claims the whole corpus is being searched while an applied working corpus or a \
            project gate is narrowing it to a fixed document set. That sentence is the entire \
            licence for removing the always-visible Type chips; if it can be false the design's \
            honesty argument fails with it.
            """)
        #expect(caption.contains("Advanced"),
                "having said something is in force, the row must say where to find it")
    }

    @Test("a residual is named even when tokens are present")
    func residualIsStatedBesideTokens() {
        // The case a caption gated on `tokens.isEmpty` misses, and the reason `caption(_:hasTokens:)`
        // takes that flag rather than inferring it: a Date token beside an applied working corpus.
        // The corpus is the STRONGER narrowing and the token row is the surface that replaced the
        // disclosure chips, so saying only "Date · 1948" is a disclosure regression.
        var params = defaults()
        params.documentIds = ["frus1948v03/d17"]

        let caption = SearchFilterTokens.caption(parameters: params, hasTokens: true)
        #expect(caption != nil,
                "a document scope went unstated because a token happened to be on screen")
        #expect(caption?.contains("Advanced") == true)
    }

    @Test("tokens with nothing residual need no caption at all")
    func noCaptionWhenTokensTellTheWholeTruth() {
        var params = defaults()
        params.documentTypeFilter = .documentsOnly
        #expect(SearchFilterTokens.caption(parameters: params, hasTokens: true) == nil,
                "a redundant sentence beside a self-explanatory token is noise in a row this review calls dense")
    }

    @Test("each residual narrowing is named, and only when present")
    func residualsAreDetected() {
        var params = defaults()
        #expect(SearchFilterTokens.residualNarrowings(parameters: params).isEmpty)

        params.phrase = "supply chains"
        #expect(SearchFilterTokens.residualNarrowings(parameters: params) == [.phrase])

        params.excludedTerms = ["draft"]
        params.prefixWildcard = "wrist"
        params.documentIds = ["frus1961-63v06/d1"]
        #expect(Set(SearchFilterTokens.residualNarrowings(parameters: params))
                == Set([.documentScope, .phrase, .excludedTerms, .prefixWildcard]))
    }

    @Test("an empty project exclusion is not a narrowing, but a populated one is")
    func projectExclusionFollowsThePipelineContract() {
        var params = defaults()
        params.excludeDocumentIds = []
        #expect(SearchFilterTokens.residualNarrowings(parameters: params).isEmpty, """
            An EMPTY exclusion announced itself as a filter. The pipeline's own contract \
            (IndexingPipeline.swift, "an empty *exclusion* is a no-op, not 'match nothing'") makes \
            this the opposite of `documentIds`, where empty means match nothing — so this one is \
            tested non-empty and that one non-nil.
            """)

        params.excludeDocumentIds = ["frus1948v03/d17"]
        #expect(SearchFilterTokens.residualNarrowings(parameters: params) == [.projectExclusion],
                "a NOT IN over every already-read document was named by nothing in the window")
    }

    @Test("an empty excluded-terms list is not a narrowing")
    func emptyExcludedTermsIsNotResidual() {
        var params = defaults()
        params.excludedTerms = []
        #expect(SearchFilterTokens.residualNarrowings(parameters: params).isEmpty,
                "an empty array read as 'excluded terms in force' would make the caption cry wolf on every search")
    }

    // MARK: - Editors

    @Test("no token promises an editor the app does not have")
    func everyEditorExists() {
        // Years is the case: `facetYearKeys` has no editor anywhere in `SearchFilterView` — the
        // facet panel is its only producer. A chevron opening nothing is the defect class this
        // review keeps finding, so the field routes to the panel instead.
        #expect(SearchFilterField.years.editor == .facetPanel)
        // Type and front matter lose their popover controls in this change, so they must carry
        // their own menus or they become unreachable on macOS.
        #expect(SearchFilterField.type.editor == .inlineMenu)
        #expect(SearchFilterField.frontMatter.editor == .inlineMenu)
        // The remaining four are sections of the Advanced popover, which is the editor they open.
        for field in [SearchFilterField.date, .volume, .person, .tags] {
            #expect(field.editor == .advancedPopover, "\(field.rawValue) lost its editor")
        }
    }

    @Test("the type token names the value, never the default's label")
    func typeValueLabels() {
        #expect(SearchFilterTokens.typeValueLabel(.documentsOnly) == "Primary documents")
        #expect(SearchFilterTokens.typeValueLabel(.editorialNotesOnly) == "Editorial notes")
    }
}
