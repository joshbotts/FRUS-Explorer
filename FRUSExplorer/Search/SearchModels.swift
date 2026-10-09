// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// `DocumentTypeFilter`, `SearchParameters`, `PersonRollupAnchor`, `SearchResult` and the indexing
// progress types (`IndexingStage`, `IndexingProgressUpdate`, `VolumeMetadataDiscovered`,
// `IndexingProgress`) moved to FRUSCoreKit in part 2, with the search service and the indexing
// pipeline that take and return them: `FRUSCoreKit/Search/SearchParameters.swift`.

// MARK: - Search hand-offs

extension SearchParameters {

    /// Whether a hand-off carrying these parameters names a search to run: keywords, a phrase, a
    /// prefix, or a person or subject filter that runs on its own.
    ///
    /// `false` for a hand-off that only sets a scope, such as Search this volume, which applies the
    /// scope and waits for the reader to type. Both search view models' `applyHandoff(_:)` ask this, and a
    /// hand-off for which it is `true` runs as a keyword search: its parameters are the keyword
    /// engine's, and the count its sender showed (Corpus Analytics' "View N documents", a person's
    /// mention count) is a count of what that engine finds.
    ///
    /// An empty string counts as nothing, as it did where `SearchView.consumePendingSearch` wrote this
    /// rule out before #1596.
    var namesASearchToRun: Bool {
        !(keywords ?? "").isEmpty
            || !(phrase ?? "").isEmpty
            || !(prefixWildcard ?? "").isEmpty
            || supportsFilterOnlySearch
    }
}

// MARK: - ChecklistLoggingNotice

/// What Checklist Mode says while Log Research Sessions is off (#1592).
///
/// Checklist Mode hides a result in two ways: when the reader marks it reviewed, and when the reader
/// opens it. The second reads the reading history, and the only writer of that history
/// (`DocumentViewModel.recordReadingHistory`) writes nothing while Settings ▸ Research ▸ Research
/// Sessions ▸ Log Research Sessions is off. So with the switch off an opened result stays in the list,
/// and until this line nothing on screen said why. The owner's decision (2026-10-09): the checklist
/// keeps depending on the switch, and the app says so.
///
/// One function for both search surfaces, so iPhone, iPad and Mac cannot word it differently.
///
/// Version history:
///   1.0 — #1592: initial implementation
enum ChecklistLoggingNotice {

    /// The line to show under the checklist's banner, or `nil` when there is nothing to say.
    ///
    /// - Parameters:
    ///   - checklistMode: Whether Checklist Mode is on.
    ///   - loggingEnabled: Whether Log Research Sessions is on (`AppState.isResearchLoggingEnabled`).
    /// - Returns: The line while the mode is on and the switch is off; `nil` otherwise.
    static func text(checklistMode: Bool, loggingEnabled: Bool) -> String? {
        guard checklistMode, !loggingEnabled else { return nil }
        return String(localized: "search.checklist.loggingOff",
                      defaultValue: "Opening a result does not hide it while Log Research Sessions is off in Settings. Mark Reviewed still hides a result.")
    }
}

// MARK: - SearchSortOrder

/// Ordering applied to search results, shared by the iOS `SearchView` and the macOS Search window
/// (#305). `relevance` keeps the FTS5 BM25 order as returned; the date orders use the structured
/// `dateISO` value (undated rows last, BM25 tie-break) — see `SearchViewModel.sortedResults` and
/// `MacSearchViewModel.allSortedResults`.
/// Which engine a submitted search runs through (V-5 hybrid page).
///
/// Per-session state, deliberately not persisted: the readings/facet toggles were de-persisted
/// by owner decision (#754 / audit L-45), and a mode silently remembered across launches would
/// make tomorrow's ordinary keyword search behave inexplicably. Every session opens on Keywords.
enum SearchMode: String, CaseIterable {
    /// The shipped FTS5 route — BM25, filters, facets, concordance, the works.
    case keywords
    /// The semantic route (experimental): the query is embedded on-device and ranked by
    /// meaning against the whole corpus. Keyword-dependent readings gate off.
    case meaning

    /// Segment label.
    var label: String {
        switch self {
        case .keywords: return String(localized: "search.mode.keywords", defaultValue: "Keywords")
        case .meaning:  return String(localized: "search.mode.meaning", defaultValue: "Meaning")
        }
    }

    /// Placeholder for the query field under this engine.
    ///
    /// Keyword search wants terms; meaning search wants a question in the reader's own words.
    /// A field still reading "Keywords…" after the reader switches to Meaning is asking for the
    /// wrong input, which is the whole reason this exists.
    ///
    /// The keyword-mode wording is supplied by the caller rather than owned here, because the two
    /// search surfaces differ *deliberately*: the iOS field is a compact `.searchable` bar, while
    /// the Mac window's wide field names the three scopes it can search. Those scopes' chips sit
    /// roughly two hundred lines below the field in `SearchSheet`, so the prompt is where a Mac
    /// reader learns that notes and summaries are in play — folding both surfaces onto one string
    /// would silently drop that. Only the Meaning prompt is shared, because only it is a property
    /// of the engine rather than of the surface.
    ///
    /// - Parameter keywordPrompt: the surface's own wording for `.keywords`.
    /// - Returns: the placeholder this mode should show.
    func fieldPrompt(keywordPrompt: String) -> String {
        switch self {
        case .keywords:
            return keywordPrompt
        case .meaning:
            return String(localized: "search.meaning.placeholder",
                          defaultValue: "A question in your own words…")
        }
    }

    /// The prompt shown before any query has been run.
    ///
    /// Mode-dependent for the same reason `fieldPrompt(keywordPrompt:)` is: once the reader
    /// switches to Meaning, "Enter keywords" names the wrong input — and it sat directly beneath
    /// a field that had already stopped saying it.
    ///
    /// Unlike the field prompt, all four strings live here rather than being supplied by the
    /// caller. This surface is iOS-only — it is the final `else` of `SearchView`'s results area,
    /// and `MacSearchViewModel` has no `hasSearched` to reach an equivalent — so there is no
    /// second surface with its own wording to preserve.
    ///
    /// Not to be confused with `SemanticMeaningEmptyState`, which is the *post*-search zero
    /// surface (`hasSearched && results.isEmpty`). This one fires before any search at all.
    ///
    /// - Parameter scoped: whether a volume scope is active. The prompt names it, so a reader
    ///   who arrived via "Search this volume" knows the next query will not reach the corpus.
    /// - Returns: the prompt for this mode and scope.
    func initialPrompt(scoped: Bool) -> String {
        switch (self, scoped) {
        case (.keywords, false):
            return String(localized: "search.prompt",
                          defaultValue: "Enter keywords to search the FRUS corpus.")
        case (.keywords, true):
            return String(localized: "search.prompt.scoped",
                          defaultValue: "Enter keywords to search within the selected volumes.")
        case (.meaning, false):
            return String(localized: "search.prompt.meaning",
                          defaultValue: "Ask a question to search the FRUS corpus by meaning.")
        case (.meaning, true):
            return String(localized: "search.prompt.meaning.scoped",
                          defaultValue: "Ask a question to search within the selected volumes.")
        }
    }
}

enum SearchSortOrder: CaseIterable {
    case relevance
    case dateAscending
    case dateDescending

    /// Short control label.
    var label: String {
        switch self {
        case .relevance:      return String(localized: "search.sort.relevance", defaultValue: "Relevance")
        case .dateAscending:  return String(localized: "search.sort.dateAscending", defaultValue: "Date ↑")
        case .dateDescending: return String(localized: "search.sort.dateDescending", defaultValue: "Date ↓")
        }
    }
}

// MARK: - SearchDefaults

/// User-configurable default search scope, persisted by the Settings
/// "Search Defaults" pane (iOS) / "Search" pane (macOS) and applied when a
/// search view model is created.
///
/// Per-session changes in the search filter panel override these values without
/// writing them back — the footer text in both settings panes documents exactly
/// that contract. `SearchViewModel` (iOS) seeds its scope properties from here
/// and `clearFilters()` resets to these values; `MacSearchViewModel` applies
/// them in its initialiser.
public enum SearchDefaults {

    /// UserDefaults key for the "search document text by default" toggle.
    public static let scopeDocumentsKey = "frus.search.scopeDocuments"
    /// UserDefaults key for the "include research notes by default" toggle.
    public static let scopeNotesKey = "frus.search.scopeNotes"
    /// UserDefaults key for the "include AI summaries by default" toggle.
    public static let scopeSummariesKey = "frus.search.scopeSummaries"
    /// UserDefaults key for the default document-type filter
    /// (`"all"` / `"documentsOnly"` / `"editorialNotesOnly"`).
    public static let typeFilterKey = "frus.search.defaultTypeFilter"

    /// Whether document body text is searched by default. Default `true`.
    public static var scopeDocuments: Bool {
        UserDefaults.standard.object(forKey: scopeDocumentsKey) as? Bool ?? true
    }

    /// Whether research notes are included in search by default. Default `true`.
    public static var scopeNotes: Bool {
        UserDefaults.standard.object(forKey: scopeNotesKey) as? Bool ?? true
    }

    /// Whether AI summaries are included in search by default. Default `true`.
    public static var scopeSummaries: Bool {
        UserDefaults.standard.object(forKey: scopeSummariesKey) as? Bool ?? true
    }

    /// The default document-type filter. Default `.all`.
    public static var documentTypeFilter: DocumentTypeFilter {
        switch UserDefaults.standard.string(forKey: typeFilterKey) {
        case "documentsOnly":      return .documentsOnly
        case "editorialNotesOnly": return .editorialNotesOnly
        default:                   return .all
        }
    }

    // MARK: - Result-preview snippet length (#189-C)

    /// UserDefaults key for the global default result-preview snippet length (1–10 lines).
    public static let snippetLineCountKey = "frus.search.snippetLineCount"
    /// UserDefaults key for the main-search snippet-length override (`0` = follow the global default).
    public static let snippetLineCountMainOverrideKey = "frus.search.snippetLineCount.mainOverride"
    /// UserDefaults key for the add-document sheet snippet-length override (`0` = follow the global).
    public static let snippetLineCountAddDocOverrideKey = "frus.search.snippetLineCount.addDocOverride"

    /// The global default snippet length in rendered lines when unset. Used as the `@AppStorage`
    /// default for the global picker; overrides default to `0` ("follow global").
    public static let defaultSnippetLineCount = 2

    /// Resolves the effective snippet length for a surface: a `0` override follows the global
    /// default; any other value overrides it. Both inputs are clamped to 1…10 so a stray stored
    /// value can never yield `.lineLimit(0)` (which would hide the snippet entirely).
    public static func effectiveSnippetLineCount(global: Int, override: Int) -> Int {
        let clampedGlobal = min(max(global, 1), 10)
        return override == 0 ? clampedGlobal : min(max(override, 1), 10)
    }

    /// A localized "1 line" / "N lines" label for a snippet length, shared by the settings and
    /// per-surface override pickers.
    public static func snippetLinesLabel(_ n: Int) -> String {
        n == 1
            ? String(localized: "settings.search.snippet.oneLine", defaultValue: "1 line")
            : String(format: String(localized: "settings.search.snippet.nLines %lld", defaultValue: "%lld lines"), Int64(n))
    }
}

// MARK: - SearchTip

/// One row of the search-syntax reference both Search surfaces render: the Search Tips sheet on iOS and iPadOS, and
/// the Tips panel in the macOS Search window (#1299).
///
/// `syntaxRows` is the one array both views and `SearchTipsTests` read, so a row cannot say one thing on screen and be
/// tested as another. The test switches exhaustively over `ID` and parses each row's own `example` through
/// `FTS5InlineQueryParser.parseDetailed`, the parse `SearchService` runs; the claims that belong to SQLite rather than
/// the parser — stemming, a prefix matched against stems, NEAR's distance, a phrase's order, the exact-word
/// post-filter — it executes against an in-memory `porter unicode61` table.
///
/// It replaces the literals the macOS panel typed beside the parser, which drifted from it: the NEAR row gave neither
/// the default distance nor what cannot go inside, the date row named an attribute the index no longer prefers, the
/// person row said "across volumes" of a filter that matches one per-volume reference, and the scope row said a change
/// persisted when nothing writes it back.
///
/// **An example is syntax, not prose.** It is verbatim ASCII, typed exactly as shown, and never localized — a
/// translated `OR` or a typographic quotation mark would be a different query. `spokenExample` and `detail` are
/// localized, each under a literal key, because `EditableContentKeyTests` finds a key only as a quoted literal in the
/// file its `Docs/EditableContent.md` block names.
///
/// Version history:
///   1.0 — #1299: initial implementation — thirteen rows; the prefix row warns that a prefix is matched against word
///         stems, so a long one misses forms whose stem is shorter (owner decision Q6), and the NEAR row says OR, NOT
///         and parentheses cannot go inside and that only NOT NEAR(…) excludes, describing no fallback (Q7). Corrected
///         in place before shipping by the #1299 follow-up, each against the parser and SQLite: the prefix row said
///         `negotiat*` finds nothing (it finds `negotiatory`, 21 times in the shipped corpus); the exact-word row said
///         `=` matches a word "only as you typed it" (it folds capitalization, a single accent and edge punctuation,
///         so `=Hull` still counts a ship's hull) and omitted NEAR(…), inside which the mark is dropped; and the last
///         row said every exclusion-only OR alternative is left out (in parentheses beside a word it is searched
///         exactly). And by #1299 round 2: the exact-word row's "always" list also omitted a word the index splits into
///         several terms, on which the mark is dropped too (`=anti-Communist` still counts anti-Communists)
struct SearchTip: Identifiable, Sendable, Equatable {

    /// Which rule a row explains. `allCases` is the order the rows are shown in.
    enum ID: String, CaseIterable, Sendable {
        /// Words side by side must all appear, in any order.
        case allWords
        /// A word also matches its other forms.
        case stemming
        /// Words in quotation marks must appear together, in order.
        case phrase
        /// `OR` finds either side, and divides everything before it from everything after it.
        case either
        /// `AND`, `OR` and `NOT` are operators in any case, so a phrase holding one is quoted.
        case operatorWords
        /// A touching minus sign, or `NOT`, leaves a word out.
        case exclude
        /// An exclusion stops at `OR` unless the alternatives are grouped.
        case excludeAcrossOr
        /// Parentheses group alternatives.
        case group
        /// `NOT`, or a minus sign touching the parenthesis, leaves out a whole group.
        case excludeGroup
        /// A trailing `*` finds words beginning with a prefix, matched against stems.
        case prefix
        /// `NEAR(…)` finds words within a distance of each other.
        case near
        /// `=` turns stemming off for one word.
        case exactWord
        /// A query needs something positive to find.
        case needsAWord
    }

    /// The rule this row explains.
    let id: ID

    /// What the reader types, verbatim ASCII. Never localized: it is syntax, and the test parses it.
    let example: String

    /// `example` as VoiceOver should say it, with its symbols named in words. Localized.
    let spokenExample: String

    /// What `example` does. Localized.
    let detail: String

    /// The row as one VoiceOver element: the spoken example, then the detail.
    var accessibilityLabel: String { "\(spokenExample). \(detail)" }

    /// Every row, in `ID.allCases` order — what both views render and the test reads.
    ///
    /// Computed rather than a `static let`, so a locale change that recreates a view reaches the strings.
    static var syntaxRows: [SearchTip] { ID.allCases.map(SearchTip.init(id:)) }

    /// The row for `id`.
    ///
    /// A switch rather than a table, so a rule added to `ID` without a row does not compile.
    init(id: ID) {
        self.id = id
        switch id {
        case .allWords:
            example = "berlin crisis"
            spokenExample = String(localized: "search.tips.allWords.spoken", defaultValue: "berlin crisis")
            detail = String(localized: "search.tips.allWords.detail",
                            defaultValue: "Finds documents containing every word, in any order.")
        case .stemming:
            example = "negotiate"
            spokenExample = String(localized: "search.tips.stemming.spoken", defaultValue: "negotiate")
            detail = String(localized: "search.tips.stemming.detail",
                            defaultValue: "Each word also matches its other forms, so negotiate finds negotiated and negotiations.")
        case .phrase:
            example = "\"cold war\""
            spokenExample = String(localized: "search.tips.phrase.spoken", defaultValue: "quote, cold war, quote")
            detail = String(localized: "search.tips.phrase.detail",
                            defaultValue: "Words in double quotation marks, straight or curly, must appear together and in that order. A phrase cannot contain quotation marks of its own.")
        case .either:
            example = "rusk OR bundy"
            spokenExample = String(localized: "search.tips.either.spoken", defaultValue: "rusk OR bundy")
            detail = String(localized: "search.tips.either.detail",
                            defaultValue: "Finds documents with either word. OR divides everything before it from everything after it, so use parentheses to limit it.")
        case .operatorWords:
            example = "\"will not intervene\""
            spokenExample = String(localized: "search.tips.operatorWords.spoken",
                                   defaultValue: "quote, will not intervene, quote")
            detail = String(localized: "search.tips.operatorWords.detail",
                            defaultValue: "AND, OR and NOT work in any case, so put a phrase that contains and, or or not in quotation marks.")
        case .exclude:
            example = "vietnam -laos"
            spokenExample = String(localized: "search.tips.exclude.spoken", defaultValue: "vietnam, minus sign, laos")
            detail = String(localized: "search.tips.exclude.detail",
                            defaultValue: "A minus sign touching a word, or NOT before it, leaves out documents containing that word, wherever it sits among the words typed with it.")
        case .excludeAcrossOr:
            example = "(cold OR war) -korea"
            spokenExample = String(localized: "search.tips.excludeAcrossOr.spoken",
                                   defaultValue: "open parenthesis, cold OR war, close parenthesis, minus sign, korea")
            detail = String(localized: "search.tips.excludeAcrossOr.detail",
                            defaultValue: "An exclusion does not reach across OR. To exclude a word from every alternative, put the alternatives in parentheses.")
        case .group:
            example = "(aqaba OR tiran) navig*"
            spokenExample = String(localized: "search.tips.group.spoken",
                                   defaultValue: "open parenthesis, aqaba OR tiran, close parenthesis, navig, star")
            detail = String(localized: "search.tips.group.detail",
                            defaultValue: "Parentheses group alternatives, and the group must match along with the words beside it.")
        case .excludeGroup:
            example = "vietnam -(laos OR cambodia)"
            spokenExample = String(localized: "search.tips.excludeGroup.spoken",
                                   defaultValue: "vietnam, minus sign, open parenthesis, laos OR cambodia, close parenthesis")
            detail = String(localized: "search.tips.excludeGroup.detail",
                            defaultValue: "NOT, or a minus sign touching the parenthesis, leaves out everything the group matches. A minus sign followed by a space is ignored.")
        case .prefix:
            example = "negoti*"
            spokenExample = String(localized: "search.tips.prefix.spoken", defaultValue: "negoti, star")
            detail = String(localized: "search.tips.prefix.detail",
                            defaultValue: "Finds words beginning with these letters. Keep the prefix short, because it is matched against word stems: negotiat* misses negotiations, which negoti* finds.")
        case .near:
            example = "NEAR(military europe, 5)"
            spokenExample = String(localized: "search.tips.near.spoken",
                                   defaultValue: "NEAR, open parenthesis, military europe, comma, 5, close parenthesis")
            detail = String(localized: "search.tips.near.detail",
                            defaultValue: "Finds the words within 5 words of each other, in either order, or within 10 when you leave out the number. The words may be phrases or prefixes. OR, NOT, AND, a minus sign and parentheses cannot go inside one, and a search that puts them there is refused rather than run as something else. Only NOT NEAR(…) excludes a NEAR; a minus sign before it does not.")
        case .exactWord:
            example = "=containment"
            spokenExample = String(localized: "search.tips.exactWord.spoken", defaultValue: "equals sign, containment")
            detail = String(localized: "search.tips.exactWord.detail",
                            defaultValue: "Turns off stemming for this word, so containment no longer matches contain or containing. Capitalization, a single accent, and/or punctuation at either end still do not matter. The = is ignored where a match need not contain the word, such as one side of an OR, and always on a prefix, inside NEAR(…), or on a word the index splits into several terms, such as anti-Communist or U.S.S.R.")
        case .needsAWord:
            example = "-korea"
            spokenExample = String(localized: "search.tips.needsAWord.spoken", defaultValue: "minus sign, korea")
            detail = String(localized: "search.tips.needsAWord.detail",
                            defaultValue: "A search needs a word to find. A query made only of exclusions does not run, and an OR alternative made only of exclusions is left out and marked NOT APPLIED in the Query Inspector, unless its parentheses sit beside a word to search for.")
        }
    }
}

// MARK: - SearchTipNote

/// A note shown with the search-syntax rows (#1299): what a filter does, where the scope and its defaults live on each
/// platform, and what Meaning mode does with the syntax.
///
/// Every case is declared on every platform and the view chooses, so the iOS-hosted test reads the macOS wording too.
/// There is no person note, by owner decision (#1299 Q1): its accurate form rests on an unmeasured question, whether
/// one per-volume person reference recurs for different people in other volumes.
///
/// Version history:
///   1.0 — #1299: initial implementation
enum SearchTipNote: String, CaseIterable, Identifiable, Sendable {
    /// What a date filter keeps and leaves out, on both platforms.
    case dates
    /// Where iOS and iPadOS set the search scope, and that a change there is not saved as a default.
    case scopeIOS
    /// Where the macOS Search window sets the search scope, and that a change there is not saved as a default.
    case scopeMac
    /// Shown INSTEAD of the syntax rows in Meaning mode, where none of the syntax applies (#1299 Q3).
    ///
    /// Its wording departs from the design brief's §2.3 draft in three ways, each to match what the reader sees: the
    /// mode names are capitalized, as the Keywords and Meaning picker labels are; it says "your words" rather than
    /// "your question", beside a field that asks for "a question in your own words" and a reader who typed operators
    /// rather than a question; and it names AND, a minus sign and parentheses beside the brief's OR, NOT, *, NEAR and =,
    /// since the rows teach all of them.
    ///
    /// **What makes it true is the Meaning route, not the absence of a parser in the app.** `SemanticQuerySearcher`
    /// hands the typed text to the encoder as written, behind its fixed query prefix, so a mark there is only more
    /// text. The one place the route did read syntax was its filter intersection: `SemanticSearchBackend.run`
    /// intersects the hits with `SearchService.filterKeySet(parameters:)`, which built the exact-word post-filter from
    /// the typed `keywords`, so a `=word` removed every hit whose document lacks the literal word — on iOS and iPadOS
    /// from the live field, on the Mac from a restored or handed-off search's keywords. Since #1299 round 2 that method
    /// removes `keywords` before building the filters, so only the filters the reader set narrow a Meaning search, and
    /// this note holds on both platforms.
    case meaningMode

    /// `Identifiable` conformance for `ForEach`.
    var id: String { rawValue }

    /// The notes the iOS and iPadOS sheet shows under the syntax rows in Keywords mode.
    static let filterNotesIOS: [SearchTipNote] = [.dates, .scopeIOS]

    /// The notes the macOS Tips panel shows under the syntax rows in Keywords mode.
    static let filterNotesMac: [SearchTipNote] = [.dates, .scopeMac]

    /// The note's text. Localized.
    ///
    /// `dates` states `IndexingPipeline`'s filter: the document's `[date_iso, date_iso_max]` interval must overlap the
    /// range, and a row with no `date_iso` never matches. The two scope notes state that the per-session scope is
    /// seeded from `SearchDefaults` and never written back: `SearchViewModel` reads the defaults once and
    /// `MacSearchViewModel`'s scope `didSet`s update only the search parameters, while the only writer of the keys is
    /// the Settings pane.
    var text: String {
        switch self {
        case .dates:
            return String(localized: "search.tips.note.dates",
                          defaultValue: "A date filter keeps documents whose dates overlap the range you set, and leaves out documents with no date.")
        case .scopeIOS:
            return String(localized: "search.tips.note.scope.ios",
                          defaultValue: "Filters ▸ Search Scope sets what a search reads. Its defaults live in Settings ▸ Reading & Search ▸ Search, and a change made in Filters is not saved as a default.")
        case .scopeMac:
            return String(localized: "search.tips.note.scope.mac",
                          defaultValue: "The Search in chips set what this window searches. Their defaults live in Settings ▸ Reading & Search ▸ Search, and a change made with the chips is not saved as a default.")
        case .meaningMode:
            return String(localized: "search.tips.note.meaningMode",
                          defaultValue: "These tips are for Keywords search. A Meaning search reads your words as a whole, so quotation marks, AND, OR, NOT, a minus sign, parentheses, *, NEAR and = have no special effect.")
        }
    }
}

// MARK: - SearchQueryRefusal

/// What a keyword search shows when its query holds nothing it can search for, or it has nowhere to search (#1299).
///
/// `SearchService` throws `FTS5Error.emptyQuery` when the parse refuses a query — nothing positive once its negations
/// apply (`-korea`), an approximation that could match nothing, or groups nested past
/// `FTS5InlineQueryParser.maximumGroupDepth` — and neither host mapped it. `FTS5Error` has no `LocalizedError`
/// conformance, so iOS's Search Error screen read "The operation couldn’t be completed. (FRUSExplorer.FTS5Error
/// error 5.)". `SearchViewModel.search()` and `MacSearchViewModel.performSearch` now pass every keyword-search failure
/// through `readable(_:for:)`.
///
/// **The service throws the same error for a query that parses when every content scope is off**, which iOS's
/// Filters ▸ Search Scope allows, and until the #1299 follow-up that reader still saw "FTS5Error error 5". It now
/// reads `everyScopeOff`, naming where a scope is turned back on. The Mac never reaches it: `performSearch` guards all
/// three Search in chips off with `MacSearchError.emptyScope` before calling the service, and `readable` answers with
/// that same error on macOS, so a Mac reader is never sent to an iOS control.
///
/// **Mapped here, in the app, rather than as a `LocalizedError` conformance on `FTS5Error`**, for three reasons:
/// - The message points at Search Tips, which is app UI. `FTS5Store` is also a SwiftPM library the generators link,
///   and it names no screen.
/// - `emptyQuery` has two causes. `SearchService.makeMatchExpressions` also throws it for a query that parses when
///   every content scope is off, which iOS's Filters sheet allows. A conformance cannot see the parameters, so it would
///   tell that reader their query only excludes words. This reads the parse the service and the Query Inspector read,
///   `SearchService.parsedQuery(for:)`, and tells the two causes apart.
/// - Nothing else changes. `FacetPanelView` matches `case FTS5Error.emptyQuery` and describes other failures with
///   `String(describing:)`, `IndexingPipeline` throws `emptyQuery` internally, and every other site that shows an
///   error's `localizedDescription` keeps the text it had; a conformance would have changed it for every `FTS5Error`
///   case at every such site.
///
/// The message says "for example" of its two reasons on purpose. The parse also refuses text with nothing searchable
/// in it at all, a lone `"` or `(`, for which neither reason is true; the Query Inspector's refused line withholds
/// itself there (`QueryInspector.refusesSomethingSearchable(_:)`), but a submitted search has to say something.
///
/// Version history:
///   1.0 — #1299: initial implementation
///   1.1 — #1299 follow-up: `everyScopeOff`, so every scope off reads as a message rather than "FTS5Error error 5".
///         Corrected in place by #1299 round 2: its message named "every search scope", but Filters ▸ Search Scope also
///         holds Include front matter, on by default and not read by `readable`, so it names the three toggles instead
/// Which set the Filters ▸ My Tags counts describe (#1310).
///
/// The counts caption says "documents in your current results", and until this existed that was
/// false in Meaning mode: the loader rebuilt a keyword AND from the typed question and counted
/// tags over it, so any `=`, `-` or phrase mark took its keyword effect and the numbers described
/// a third set — neither the results on screen nor the corpus.
///
/// **A host must freeze this when a search COMPLETES, never derive it when the panel opens.**
/// `lastRunWasSemantic` and `hasSearched` are both written before the await, so a panel opened
/// while a search is in flight would combine the new run's route with the old run's results.
enum UserTagCountScope: Sendable {
    /// Count over the FTS match the executed keyword search ran — the parameters that RAN, never
    /// the live field.
    case match(SearchParameters)
    /// Count over these result keys, as the semantic route produces them. They are already
    /// intersected with the filters by the backend, so the loader applies none.
    case resultKeys([DocumentKey])

    /// One result's identity, as the counts need it.
    struct DocumentKey: Sendable, Equatable {
        let volumeId: String
        let documentId: String
    }
}

enum SearchQueryRefusal: LocalizedError, Equatable, Sendable {
    /// The query's parse rendered no expression, so there is nothing to search for.
    case nothingToSearch
    /// A `NEAR(…)` in the query holds something FTS5 forbids — a boolean, a `-` exclusion, a nested group — or a
    /// distance it will not parse (#1304). Refused rather than degraded, because the degraded search was a DIFFERENT
    /// search: the distance was looked for as a word, and a `-` inside became a corpus-wide exclusion.
    case malformedProximity(text: String)
    /// The query parses, but every content scope — document text, summaries and research notes — is off, so there is
    /// nowhere to search. The wording names those three toggles rather than "every scope", because iOS's Filters ▸ Search
    /// Scope also holds Include front matter, which is not somewhere to search and may still be on; macOS answers with
    /// `MacSearchError.emptyScope`.
    case everyScopeOff

    /// The reader-facing message. Localized.
    var errorDescription: String? {
        switch self {
        case .nothingToSearch:
            return String(localized: "search.error.refusedQuery",
                          defaultValue: "This query has nothing it can search for: for example, it only excludes words, or its groups are nested too deeply. See Search Tips for what a search needs.")
        case .everyScopeOff:
            return String(localized: "search.error.emptyScope.ios",
                          defaultValue: "Document text, summaries and research notes are all turned off, so there is nothing to search. Turn one on in Filters ▸ Search Scope.")
        case .malformedProximity(let text):
            return String(format: String(
                localized: "search.error.malformedNear %@",
                defaultValue: "%@ cannot be searched as written: a NEAR(…) holds only words, phrases and prefixes, with an optional distance. OR, NOT, AND, a minus sign and parentheses cannot go inside one. Nothing was searched, because dropping the NEAR would run a different search."),
                text)
        }
    }

    /// What a keyword-search failure shows the reader, in place of `FTS5Error.emptyQuery`: `nothingToSearch` when the
    /// query's own parse refused it, whatever the scope — turning a scope on would not run it — and, when the parse
    /// renders but every content scope is off, `everyScopeOff` (on macOS, `MacSearchError.emptyScope`). Every other
    /// error, and `emptyQuery` with a scope on, is returned unchanged.
    ///
    /// - Parameters:
    ///   - error: What the search threw.
    ///   - parameters: The parameters the search ran with — the same value, so the parse read here is the one that ran.
    /// - Returns: The error to store and show.
    static func readable(_ error: any Error, for parameters: SearchParameters) -> any Error {
        guard case FTS5Error.emptyQuery = error else { return error }
        let parsed = SearchService.parsedQuery(for: parameters)
        // #1304 first: "nothing it can search for" is TRUE of a malformed proximity search and
        // tells the reader nothing about what to change, so the specific reason wins.
        if let reason = parsed.malformedProximity {
            return SearchQueryRefusal.malformedProximity(text: reason.text)
        }
        if parsed.expression == nil {
            return SearchQueryRefusal.nothingToSearch
        }
        guard !parameters.includeDocumentText, !parameters.includeSummaries, !parameters.includeNotes else {
            return error
        }
        #if os(macOS)
        return MacSearchError.emptyScope
        #else
        return SearchQueryRefusal.everyScopeOff
        #endif
    }
}
