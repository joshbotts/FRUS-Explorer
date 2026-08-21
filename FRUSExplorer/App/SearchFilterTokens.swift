// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SearchFilterField

/// A filter the macOS Search window's token row can show (UI review M-4, design option 3a).
///
/// Seven fields, in the order they are offered and displayed. The order is **fixed**, not
/// most-recently-used: a seven-item menu that rearranges itself under the reader's hand costs
/// them the position they just learned, and a token row whose tokens move when a value changes is
/// harder to read than one where Date is always first. (The design brief asks for
/// recently-used-first; this is the one place it is not followed, and it is a one-line change if
/// the owner disagrees.)
enum SearchFilterField: String, CaseIterable, Identifiable, Sendable {
    case date
    case years
    case volume
    case person
    case tags
    case type
    case frontMatter
    case subject

    var id: String { rawValue }

    /// The field name shown at the head of a token and in the + Filter menu.
    var displayName: String {
        switch self {
        case .date:        return String(localized: "search.token.field.date", defaultValue: "Date")
        case .years:       return String(localized: "search.token.field.years", defaultValue: "Years")
        case .volume:      return String(localized: "search.token.field.volume", defaultValue: "Volume")
        case .person:      return String(localized: "search.token.field.person", defaultValue: "Person")
        case .tags:        return String(localized: "search.token.field.tags", defaultValue: "Tags")
        case .type:        return String(localized: "search.token.field.type", defaultValue: "Type")
        case .frontMatter: return String(localized: "search.token.field.frontMatter",
                                         defaultValue: "Front matter")
        case .subject:     return String(localized: "search.token.field.subject",
                                         defaultValue: "Subject")
        }
    }

    /// Where this field is actually edited in this codebase.
    ///
    /// **This distinction is a finding, not a detail.** The design says every token "reopens that
    /// same editor", which reads as though all seven have one. Measured against
    /// `SearchFilterView.swift`, they do not: four are sections of the Advanced popover
    /// (`dateRangeSection:381`, `customScopeSection:718` + the volume picker, `personSection:447`,
    /// `userTagsSection:546`), two become inline menus once their duplicate popover controls are
    /// removed, and **Years has no editor anywhere** — `facetYearKeys` is written only by the facet
    /// panel and by `syncToFilterVM`. A Years token drawn with an edit chevron would be a control
    /// that promises an editor the app does not have, which is the defect class this whole review
    /// keeps finding. So it points at the facet panel, which is where a year set comes from.
    var editor: Editor {
        switch self {
        case .type, .frontMatter: return .inlineMenu
        // Subjects joins Years as facet-panel-only: the Advanced popover has no subject control,
        // and #308 deliberately did not add one — the bucket is chosen from a breakdown of THIS
        // result set, which a standing filter list cannot show.
        case .years, .subject:    return .facetPanel
        case .date, .volume, .person, .tags: return .advancedPopover
        }
    }

    /// How a token's value is changed.
    enum Editor: Sendable {
        /// A menu on the token itself — the field has few enough values to list.
        case inlineMenu
        /// The Advanced popover, which holds this field's only editor.
        case advancedPopover
        /// The facet panel, the only producer of this field's value.
        case facetPanel
    }
}

// MARK: - SearchFilterToken

/// One active filter, as the token row draws it.
struct SearchFilterToken: Identifiable, Equatable, Sendable {
    /// Which filter this is.
    let field: SearchFilterField
    /// The value, already localized and short enough for a capsule.
    let value: String

    var id: String { field.rawValue }
}

// MARK: - SearchFilterTokens

/// The token row's contents, derived from search state rather than stored beside it.
///
/// ## Why this is a projection and not a model
/// Every filter producer in the app — the facet panel's narrowing, the Advanced popover's live
/// edits, a `pendingSearch` hand-off, a recalled saved search, an applied working corpus — already
/// writes `SearchParameters`. A parallel token model would be a second place for the same fact,
/// and the two would eventually disagree; the disagreement would look like a filter that is in
/// force with nothing on screen saying so, which is #775 exactly.
///
/// ## The honesty problem this type exists to make impossible
/// The design's at-rest caption states the whole default in words — *"no filters — all types,
/// front matter included, everything indexed"* — and that sentence is what licenses removing the
/// always-visible Type chips. **It is also a claim that can be false.** `SearchParameters` carries
/// narrowings that none of the seven tokens represent:
///
/// - `documentIds` — an applied working corpus, a project History gate, or both intersected
/// - `phrase`, `excludedTerms`, `prefixWildcard` — set in the Advanced popover
///
/// With any of those in force the corpus is emphatically not "everything indexed". So the caption
/// is not a constant: ``residualNarrowings(parameters:)`` names what the tokens cannot, and the
/// row says *that* instead. `MacSearchViewModel.activeFilterSummary` already enumerates the same
/// set for the Advanced button's tint — it covers everything here **except** `documentTypeFilter`
/// and `includeFrontMatter`, which today have their own always-visible row and, after this change,
/// have tokens.
///
/// Version history:
///   1.0 — M-4 / design option 3a
enum SearchFilterTokens {

    /// The label strings the view model already computes, passed in so this stays a pure function.
    ///
    /// Each is `nil` exactly when its filter is inactive, which is the same predicate the shipped
    /// `filterRow` used for `isActive` — so a token appears under precisely the conditions a chip
    /// showed a value before.
    struct Labels: Equatable, Sendable {
        var date: String?
        var years: String?
        var volume: String?
        var person: String?
        var tags: String?

        init(date: String? = nil, years: String? = nil, volume: String? = nil,
             person: String? = nil, tags: String? = nil) {
            self.date = date
            self.years = years
            self.volume = volume
            self.person = person
            self.tags = tags
        }
    }

    /// Every filter currently narrowing the search, as tokens.
    ///
    /// - Parameters:
    ///   - parameters: The executed search parameters.
    ///   - labels: The view model's computed labels.
    /// - Returns: Tokens in `SearchFilterField.allCases` order — stable, so a token does not move
    ///   when a different one's value changes.
    static func tokens(parameters: SearchParameters, labels: Labels) -> [SearchFilterToken] {
        SearchFilterField.allCases.compactMap { field in
            value(for: field, parameters: parameters, labels: labels)
                .map { SearchFilterToken(field: field, value: $0) }
        }
    }

    /// The fields with no token, which are what the + Filter menu can still add.
    static func addableFields(parameters: SearchParameters, labels: Labels) -> [SearchFilterField] {
        let active = Set(tokens(parameters: parameters, labels: labels).map(\.field))
        return SearchFilterField.allCases.filter { !active.contains($0) }
    }

    /// The displayed value for one field, or `nil` when that field is at its default.
    ///
    /// **A default is an absence, uniformly.** Type shows a token only away from `.all`, and front
    /// matter only when excluded — the same rule every other field already followed, which is what
    /// makes "no token means the default" true rather than true-except-for-two.
    ///
    /// ## Why "default" here means `.all` and not the user's Settings preference
    /// `MacSearchViewModel.init` seeds `documentTypeFilter` from `SearchDefaults`, so a reader who
    /// has set "Editorial notes only" in Settings opens a **fresh** Search window already carrying
    /// a Type token they did not create. That looks wrong for a row whose premise is "these are the
    /// filters you applied", and the obvious repair — show the token only when the value differs
    /// from `SearchDefaults.documentTypeFilter` — is worse, in two ways that this file's own
    /// invariants make plain:
    ///
    /// - The search **is** narrowed. Hiding the token would put an in-force filter on screen
    ///   nowhere, for exactly the readers who set the preference, while
    ///   ``atRestCaption(parameters:)`` went on saying "all types". That is #775 with a new coat.
    /// - The remove button would stop removing. `×` resets Type to `.all`; if the token's
    ///   visibility keyed on the Settings default, a reader whose default is "Editorial notes only"
    ///   would press `×` and watch the token stay — a control that moves and changes nothing.
    ///
    /// So the token is telling the truth, and the surprise is the preference, not the row.
    static func value(for field: SearchFilterField,
                      parameters: SearchParameters,
                      labels: Labels) -> String? {
        switch field {
        case .date:   return labels.date
        case .years:  return labels.years
        case .volume: return labels.volume
        case .person: return labels.person
        case .tags:   return labels.tags
        case .type:
            guard parameters.documentTypeFilter != .all else { return nil }
            return typeValueLabel(parameters.documentTypeFilter)
        case .frontMatter:
            guard !parameters.includeFrontMatter else { return nil }
            return String(localized: "search.token.frontMatter.excluded", defaultValue: "excluded")
        case .subject:
            guard let bucket = parameters.subjectBucket else { return nil }
            // A bucket the vocabulary cannot name still produces a token. The whole point of this
            // row is that no filter is in force without something on screen saying so, and an
            // unnameable bucket is the case where that matters most.
            return DocumentSubjectStore.shared?.bucketVocabulary.label(at: bucket)
                ?? String(localized: "search.token.subject.unknown", defaultValue: "filtered")
        }
    }

    /// The token value for a non-default document-type filter.
    ///
    /// Deliberately not `DocumentTypeFilter.searchUIOptions`' labels: that table's first entry is
    /// "Both", which is the default and therefore never a token, and its other two read as menu
    /// items rather than as the tail of "Type · …".
    static func typeValueLabel(_ filter: DocumentTypeFilter) -> String {
        switch filter {
        case .all:
            return String(localized: "search.token.type.all", defaultValue: "all types")
        case .documentsOnly:
            return String(localized: "search.token.type.documents",
                          defaultValue: "Primary documents")
        case .editorialNotesOnly:
            return String(localized: "search.token.type.editorialNotes",
                          defaultValue: "Editorial notes")
        }
    }

    // MARK: - Honesty

    /// A narrowing that is in force and that no token can show.
    enum Residual: String, CaseIterable, Sendable {
        /// An applied working corpus and/or a project gate — `parameters.documentIds`.
        case documentScope
        /// Project Focus "only new" — `parameters.excludeDocumentIds`, a `NOT IN` over every
        /// document the reader has already engaged with. Named by **nothing** in the window before
        /// this: it is not a filter anyone set from here, it produces no token, and the volume
        /// token that always accompanies it describes a different narrowing entirely.
        case projectExclusion
        /// An exact-phrase constraint.
        case phrase
        /// Excluded terms.
        case excludedTerms
        /// A prefix wildcard.
        case prefixWildcard

        /// How the at-rest line names it.
        var displayName: String {
            switch self {
            case .documentScope:
                return String(localized: "search.token.residual.scope",
                              defaultValue: "a document scope")
            case .projectExclusion:
                return String(localized: "search.token.residual.exclusion",
                              defaultValue: "documents you have already read")
            case .phrase:
                return String(localized: "search.token.residual.phrase", defaultValue: "a phrase")
            case .excludedTerms:
                return String(localized: "search.token.residual.excluded",
                              defaultValue: "excluded terms")
            case .prefixWildcard:
                return String(localized: "search.token.residual.prefix",
                              defaultValue: "a prefix wildcard")
            }
        }
    }

    /// Narrowings in force that the seven tokens cannot represent.
    ///
    /// These all live in the Advanced popover, which is why the row's answer is to name them and
    /// point there rather than to grow four more tokens: a token whose editor is a popover section
    /// the reader must scroll to find is not obviously better than a sentence saying so.
    static func residualNarrowings(parameters: SearchParameters) -> [Residual] {
        var found: [Residual] = []
        if parameters.documentIds != nil            { found.append(.documentScope) }
        // **Non-empty, not non-nil**, and the asymmetry is the pipeline's own: "an empty
        // *exclusion* is a no-op, not 'match nothing'" (`IndexingPipeline.swift:3176-3179`),
        // whereas an empty `documentIds` above really does match nothing and so is a narrowing at
        // any size. Testing `!= nil` here would announce a filter on every Focus search that
        // excludes zero documents.
        if let excluded = parameters.excludeDocumentIds, !excluded.isEmpty {
            found.append(.projectExclusion)
        }
        if parameters.phrase != nil                 { found.append(.phrase) }
        if !parameters.excludedTerms.isEmpty        { found.append(.excludedTerms) }
        if parameters.prefixWildcard != nil         { found.append(.prefixWildcard) }
        return found
    }

    /// The sentence the row shows beside its tokens, or `nil` when the tokens say everything.
    ///
    /// Three cases, and the middle one is the one a naive "at-rest caption" misses:
    ///
    /// - **No tokens, nothing residual** — state the whole default, which is what licenses having
    ///   removed the always-visible Type chips.
    /// - **Residual in force** — name it, *whether or not tokens are present*. A Date token beside
    ///   an applied working corpus otherwise leaves the stronger narrowing unstated.
    /// - **Tokens, nothing residual** — say nothing; the tokens are the whole truth.
    ///
    /// - Parameters:
    ///   - parameters: The executed search parameters.
    ///   - hasTokens: Whether any token is on screen.
    static func caption(parameters: SearchParameters, hasTokens: Bool) -> String? {
        let residual = residualNarrowings(parameters: parameters)
        if residual.isEmpty {
            guard !hasTokens else { return nil }
            return String(
                localized: "search.token.atRest.none",
                defaultValue: "no filters — all types, front matter included, everything indexed")
        }
        let named = residual.map(\.displayName)
            .formatted(.list(type: .and, width: .standard))
        return String(
            format: String(localized: "search.token.caption.residual %@",
                           defaultValue: "also narrowed by %@ — see Advanced"),
            named)
    }

    /// The no-token line, kept as the name the design uses for it.
    ///
    /// - Returns: The full-default sentence when nothing at all narrows the search, and otherwise
    ///   a sentence naming what does. **Never the default sentence while something is in force** —
    ///   that is the whole point of computing it rather than writing it into the view.
    static func atRestCaption(parameters: SearchParameters) -> String {
        caption(parameters: parameters, hasTokens: false) ?? ""
    }
}
