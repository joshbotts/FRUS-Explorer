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

// MARK: - SearchLayerDirection

/// Which way a search runs inside a held list (#1577 lane 4): Search Within These Results.
///
/// The reader holds the list on screen as a base, and the search field then runs the OTHER engine
/// inside it. A keyword layer filters a Meaning list; a Meaning layer reorders a keyword list or a
/// browse. Same-engine layers and deeper stacks are left out (the owner's decision 5), so the
/// direction follows from the base and nothing else.
///
/// Version history:
///   1.0 — #1577 lane 4: initial implementation
///   1.1 — #1577 lane 7: ``swapped``, the way a swap turns a layer
enum SearchLayerDirection: Equatable, Sendable {

    /// Words found in a held Meaning list: a keyword search inside it, its rows kept closest first.
    case wordsInMatches
    /// A held keyword list or browse reordered by a question: every row of it, closest first.
    case rankByMeaning

    /// The direction a layer over rows of `route` would take, or `nil` when none can start there: a
    /// list that is already a layer, since a layer is never stacked on a layer.
    ///
    /// - Parameter route: The route that produced the rows on screen.
    /// - Returns: The direction, or `nil`.
    static func starting(over route: ExecutedSearchRoute) -> SearchLayerDirection? {
        switch route {
        case .meaning: return .wordsInMatches
        case .keywords: return .rankByMeaning
        case .wordsInMatches, .rankedByMeaning: return nil
        }
    }

    /// The other way, which a swap turns this one into (``SearchLayerSwap``): words found in a Meaning list become a
    /// ranking of the words' own results, and a ranking becomes words found in the question's closest matches.
    var swapped: SearchLayerDirection {
        switch self {
        case .wordsInMatches: return .rankByMeaning
        case .rankByMeaning: return .wordsInMatches
        }
    }

    /// The engine the field runs while the base is held: the other one from the base's.
    var fieldEngine: SearchMode {
        switch self {
        case .wordsInMatches: return .keywords
        case .rankByMeaning: return .meaning
        }
    }

    /// The engine the base came from, which the Keywords | Meaning control shows again when the
    /// reader leaves the base.
    var baseEngine: SearchMode {
        switch self {
        case .wordsInMatches: return .meaning
        case .rankByMeaning: return .keywords
        }
    }

    /// The title of the command that starts the layer, named by what it will do.
    var startTitle: String {
        switch self {
        case .wordsInMatches:
            return String(localized: "search.layer.start.wordsInMatches",
                          defaultValue: "Find Words in These Matches")
        case .rankByMeaning:
            return String(localized: "search.layer.start.rankByMeaning",
                          defaultValue: "Rank These Results by a Question")
        }
    }

    /// The search field's prompt while the base is held: what to type, and where it will run.
    var fieldPrompt: String {
        switch self {
        case .wordsInMatches:
            return String(localized: "search.layer.prompt.wordsInMatches",
                          defaultValue: "Words to find in these matches…")
        case .rankByMeaning:
            return String(localized: "search.layer.prompt.rankByMeaning",
                          defaultValue: "A question to rank these results by…")
        }
    }
}

// MARK: - PinnedResultBase

/// The list a layer runs inside, frozen when the reader chose to search within it (#1577 lane 4).
///
/// ## What it holds, and why each part
///
/// - **The rows**, in the order the search returned them, so that leaving the base puts them back
///   exactly, the ones Checklist Mode hides included.
/// - **The members**: those rows less the ones Checklist Mode was hiding when the base was held,
///   still in their order. They are the set the layer runs inside, which is the list the reader
///   saw: what Save as Working Corpus captures (`displayedResults`), and the only notion of a held
///   set the app has. A hit beyond the library has no row and is not a member; ``notDownloaded``
///   counts it.
/// - **Everything a return to the base must put back** without running a search: the route, the
///   total and the ceiling the fetch ran under, the rendered expression, the Meaning disclosure and
///   beyond-library hits, the tag-count scope, the trail's anchor and the checklist's.
///
/// A value, built from an array of rows, so that a selection of rows (#1576) can feed one later. It
/// holds no rowid (rule 6): a re-indexed volume gets new ones, and the members are keyed
/// `"volumeId/documentId"` as `SearchParameters.documentIds` keys them.
///
/// ## The trail's anchor is set aside
///
/// `SearchHistoryWriter` refreshes the row it last wrote whenever the query text is the same,
/// whatever the scope. A layer typed with the base's own words would therefore overwrite the base's
/// row, so the view model holds the base's anchor here while a layer runs, gives each layer an
/// anchor of its own, and puts the base's back when the reader leaves (rule 5).
///
/// Version history:
///   1.0 — #1577 lane 4: initial implementation
///   1.1 — #1577 lane 5: the rules a view model holds a list by, for the Mac's window as for iPhone and iPad:
///          ``members(of:shown:)``, ``kind(route:query:ran:browseName:)``, ``browseName(of:)``, and the filters'
///          ``filtersNarrow(_:)`` and ``wasFound(under:)``
///   1.2 — #1577 lane 6: a list cut at its ceiling and held for a question is ranked whole
///          (``ranksWholeMatch``): its row says "all 35,275 results", it keeps its match's keys once a ranking
///          has read them (``wholeMatch``), and its record counts the match; ``wholeMatchSetSize(for:)`` and
///          ``filtersNarrowTheMatch(_:)``, what the Meaning strip may say before a question
struct PinnedResultBase: Sendable {

    /// What kind of list the base is, for the row that names it and the record.
    enum Kind: Equatable, Sendable {
        /// A Meaning search's closest matches.
        case meaning
        /// A keyword search's results.
        case keywords
        /// A browse with no words (a person's mentions, a topic, a subject area), with its name where
        /// it has one.
        case browse(name: String?)
    }

    /// The way the layer runs.
    let direction: SearchLayerDirection
    /// What kind of list the base is.
    let kind: Kind
    /// The submitted query the base came from, trimmed, which leaving puts back in the field; empty for a
    /// browse, and for a list restored with a phrase or a prefix alone (``describedQuery``).
    let query: String
    /// Every row the base loaded, in its order: what leaving the base puts back. Its tags follow the rows on
    /// screen (``takeUserTags(from:)``).
    private(set) var rows: [SearchResult]
    /// The rows the layer runs inside: ``rows`` less those Checklist Mode was hiding, in order.
    private(set) var members: [SearchResult]
    /// Rows of the base Checklist Mode was hiding when it was held, which the layer leaves out.
    let hiddenByChecklist: Int
    /// Meaning hits in volumes the reader has not downloaded, which have no rows to search.
    let notDownloaded: Int

    /// The route that produced the base.
    let route: ExecutedSearchRoute
    /// The ceiling the base's fetch ran under (`lastFetchLimit`).
    let fetchLimit: Int
    /// The base's whole-query count, when it had one.
    let totalMatchCount: Int?
    /// The expression the base recorded for the trail.
    let renderedExpression: String?
    /// The base's Meaning disclosure, for a Meaning base.
    let disclosure: SemanticSearchBackend.Disclosure?
    /// The base's hits beyond the library, for a Meaning base.
    let beyondLibraryHits: [SemanticSearchBackend.BeyondLibraryHit]
    /// What the base's tag counts described (#1310).
    let userTagCountScope: UserTagCountScope?
    /// The trail anchor the base's own search left, set aside while a layer runs (rule 5).
    let historyAnchor: SearchHistoryWriter.Anchor?
    /// The search the base's rows came from, for the checklist and the selection.
    let completedSearchAnchor: ChecklistAnchor?
    /// The signature of the filters the base ran under, its document set included, so that a layer
    /// can say when filters changed since narrow it as well (``ResultSetScope/layerFiltersNarrowed``).
    /// Taken from the run that produced the rows, not from the fields, which may hold a filter set
    /// since and never run.
    let filterSignature: String
    /// The words a keyword list with no typed text was found by, as its row and its record name it: a
    /// phrase in quotation marks, a prefix with its asterisk (``describedWords(phrase:prefix:)``). `nil`
    /// where ``query`` says it, and for a browse.
    var describedQuery: String? = nil

    /// The members' keys, as `SearchParameters.documentIds` keys them.
    var memberKeys: [String] { members.map(\.id) }

    /// The keys of the list's whole match, as the index gave them (`SearchService.matchKeys(parameters:)`), once a
    /// ranking has read them, and `nil` before (#1577 lane 6). Kept with the list so that a second question asks
    /// the index nothing: the list is frozen, and so is its match. Keys only, never rowids (rule 6).
    private(set) var wholeMatch: [String]?

    /// Whether a question ranks this list's whole match rather than its rows (#1577 lane 6): a keyword list or a
    /// browse cut at its ceiling, held for a Meaning layer, whose search is known.
    ///
    /// Such a list is the highest-scoring slice of a larger match, a different slice on each platform, and a ranking
    /// of the slice is not a ranking of the match. So the question ranks every document of the match, and the list
    /// shows the closest up to the ceiling (`SemanticSearchBackend.rankWholeMatch(query:base:match:parameters:limit:)`).
    /// A layer of words never takes this path: words are found only inside a Meaning list, which is never cut.
    var ranksWholeMatch: Bool {
        direction == .rankByMeaning && wasCut && ranParameters != nil
    }

    /// How many documents the list's whole match holds: its search's count, or the keys a ranking read where the
    /// count failed, or `nil` while neither is known.
    var wholeMatchCount: Int? { totalMatchCount ?? wholeMatch?.count }

    /// The keys of the rows Checklist Mode was hiding when the list was held, which no layer searches: a ranking of
    /// the whole match leaves them out of it as the members leave them out of the rows.
    var hiddenKeys: Set<String> {
        Set(rows.map(\.id)).subtracting(members.map(\.id))
    }

    /// How many documents a question would rank inside this list's whole match, where that is known without reading
    /// the match (#1577 lane 6): its count less the rows hidden as reviewed, under no gate or the gate the list was
    /// found under, which narrowed its match already, and under no filter it was not found under. `nil` for a list
    /// ranked by its rows; under a gate applied since, or a filter chosen since (``filtersNarrowTheMatch(_:)``), whose
    /// intersection with the match only the keys say; and while the count is not known: the Meaning strip then says
    /// nothing in advance rather than a number the ranking would not bear out.
    ///
    /// - Parameter parameters: The parameters in force outside the held list: its document gate and its filters.
    /// - Returns: The size, or `nil`.
    func wholeMatchSetSize(for parameters: SearchParameters) -> Int? {
        let gate = parameters.documentIds
        guard ranksWholeMatch, gate == nil || gate == ranParameters?.documentIds,
              !filtersNarrowTheMatch(parameters),
              let count = wholeMatchCount else { return nil }
        return max(0, count - hiddenByChecklist)
    }

    /// Whether filters chosen since the list was held narrow its whole match (#1577 lane 6), which a ranking of it then
    /// ranks inside them (`SemanticSearchBackend.rankWholeMatch(query:base:match:parameters:limit:)`). The document
    /// gate is left out, set back to the list's own: a working corpus applied since is the gate's to narrow.
    ///
    /// - Parameter parameters: The filters in force outside the held list.
    /// - Returns: Whether they narrow the match.
    func filtersNarrowTheMatch(_ parameters: SearchParameters) -> Bool {
        var after = parameters
        after.documentIds = ranParameters?.documentIds
        return filtersNarrow(after)
    }

    /// Keeps the keys of the list's whole match, which a ranking has read, for the questions after it.
    ///
    /// - Parameter keys: The keys, as `SearchService.matchKeys(parameters:)` returned them.
    mutating func keepWholeMatch(_ keys: [String]) {
        wholeMatch = keys
    }

    /// The parameters the held list's keyword search ran with, or `nil` for a Meaning list, whose rows no match
    /// found: the match a facet over the list's own rows aggregates (#1577 lane 4's finding, on the Mac since lane 5).
    var ranParameters: SearchParameters? { userTagCountScope?.ranParameters }

    /// The words the base names itself by: ``describedQuery`` where there is one, ``query`` otherwise.
    private var shownQuery: String { describedQuery ?? query }

    /// How a list found by a restored phrase or prefix, with no typed words, names its words: `"wheat
    /// shipments"`, `embarg*`, or both. `nil` when it had neither, which makes it a browse.
    ///
    /// - Parameters:
    ///   - phrase: The run's phrase (`SearchParameters.phrase`).
    ///   - prefix: The run's prefix (`SearchParameters.prefixWildcard`).
    /// - Returns: The words, or `nil`.
    static func describedWords(phrase: String?, prefix: String?) -> String? {
        let phrase = phrase?.trimmingCharacters(in: .whitespaces) ?? ""
        let prefix = prefix?.trimmingCharacters(in: .whitespaces) ?? ""
        let parts = [phrase.isEmpty ? nil : "\"\(phrase)\"", prefix.isEmpty ? nil : "\(prefix)*"].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Gives the held rows the tags the same documents carry in `shown`, the rows on screen (#1576 lane
    /// 5's refresh writes those alone). Tags given to a layer's rows, or to the base's own while they
    /// were on screen, then last into the next layer and back to the list on leaving.
    ///
    /// - Parameter shown: The rows on screen.
    mutating func takeUserTags(from shown: [SearchResult]) {
        let tags = Dictionary(shown.map { ($0.id, $0.userTagIds) }, uniquingKeysWith: { first, _ in first })
        guard !tags.isEmpty else { return }
        func carried(_ row: SearchResult) -> SearchResult {
            guard let ids = tags[row.id], ids != row.userTagIds else { return row }
            return row.replacingUserTagIds(Set(ids.compactMap(UUID.init(uuidString:))))
        }
        rows = rows.map(carried)
        members = members.map(carried)
    }

    /// Each member's Meaning score, for a Meaning base: what a keyword layer's rows carry on their
    /// chips, so that a row found by its words still says how close it was.
    var scoreByKey: [String: Double] {
        Dictionary(members.compactMap { row in row.semanticScore.map { (row.id, $0) } },
                   uniquingKeysWith: { first, _ in first })
    }

    /// Whether the base's fetch stopped short of the whole match: a keyword list at its ceiling, or
    /// one whose total is larger than what it loaded. A Meaning list never is (#1595).
    var wasCut: Bool {
        guard kind != .meaning else { return false }
        if rows.count >= fetchLimit { return true }
        if let totalMatchCount { return totalMatchCount > rows.count }
        return false
    }

    // MARK: - The row that names the base

    /// "100 closest matches to “how did the embassy…”", "212 results for “offset agreement”", "all
    /// 35,275 results for “negotiations”": the set, as the row that names the base says it after
    /// "Within".
    ///
    /// Counted by its members, the rows the layer runs inside, which is what the list showed. Where
    /// the base was cut at its fetch ceiling the sentence says so, as the assessment's design
    /// requires: the members are then the highest-scoring slice of a larger match, and a ranking of
    /// them is not a ranking of it. "The first 1,000" is the fetch, so it counts every row loaded;
    /// what Checklist Mode hid among them is ``leftOutDescription``'s to say.
    ///
    /// Since #1577 lane 6 a cut list held for a question is ranked whole (``ranksWholeMatch``), and the
    /// row says so instead: "all 35,275 results for “negotiations”", counted by the match, or "every
    /// result for “negotiations”" while its size is not known. The first slice no longer bounds the
    /// layer, so the row does not name it.
    var setDescription: String {
        let count = members.count
        switch kind {
        case .meaning:
            guard count != 1 else {
                return String(format: String(localized: "search.layer.set.meaning.one %@",
                                             defaultValue: "the closest match to “%@”"), shownQuery)
            }
            return String(format: String(localized: "search.layer.set.meaning %@ %@",
                                         defaultValue: "%1$@ closest matches to “%2$@”"),
                          count.formatted(), shownQuery)
        case .keywords:
            // A question ranks the whole match of a list cut at its ceiling (#1577 lane 6), so the row names it whole.
            if ranksWholeMatch {
                if let count = wholeMatchCount {
                    return String(format: String(localized: "search.layer.set.keywords.whole %@ %@",
                                                 defaultValue: "all %1$@ results for “%2$@”"),
                                  count.formatted(), shownQuery)
                }
                return String(format: String(localized: "search.layer.set.keywords.wholeUnknown %@",
                                             defaultValue: "every result for “%@”"),
                              shownQuery)
            }
            if wasCut {
                if let totalMatchCount {
                    return String(format: String(localized: "search.layer.set.keywords.cut %@ %@ %@",
                                                 defaultValue: "the first %1$@ of %2$@ results for “%3$@”"),
                                  rows.count.formatted(), totalMatchCount.formatted(), shownQuery)
                }
                return String(format: String(localized: "search.layer.set.keywords.cutUnknown %@ %@",
                                             defaultValue: "the first %1$@ results for “%2$@”"),
                              rows.count.formatted(), shownQuery)
            }
            return String(format: String(localized: "search.layer.set.keywords %@ %@",
                                         defaultValue: "%1$@ for “%2$@”"),
                          Self.resultsPhrase(count), shownQuery)
        case .browse(let name):
            guard let name, !name.isEmpty else {
                if ranksWholeMatch {
                    if let total = wholeMatchCount {
                        return String(format: String(localized: "search.layer.set.browse.unnamed.whole %@",
                                                     defaultValue: "all %@ results of your browse"),
                                      total.formatted())
                    }
                    return String(localized: "search.layer.set.browse.unnamed.wholeUnknown",
                                  defaultValue: "every result of your browse")
                }
                return String(format: String(localized: "search.layer.set.browse.unnamed %@",
                                             defaultValue: "%@ of your browse"),
                              Self.resultsPhrase(count))
            }
            if ranksWholeMatch {
                if let total = wholeMatchCount {
                    return String(format: String(localized: "search.layer.set.browse.whole %@ %@",
                                                 defaultValue: "all %1$@ results for %2$@"),
                                  total.formatted(), name)
                }
                return String(format: String(localized: "search.layer.set.browse.wholeUnknown %@",
                                             defaultValue: "every result for %@"),
                              name)
            }
            if wasCut {
                if let totalMatchCount {
                    return String(format: String(localized: "search.layer.set.browse.cut %@ %@ %@",
                                                 defaultValue: "the first %1$@ of %2$@ results for %3$@"),
                                  rows.count.formatted(), totalMatchCount.formatted(), name)
                }
                return String(format: String(localized: "search.layer.set.browse.cutUnknown %@ %@",
                                             defaultValue: "the first %1$@ results for %2$@"),
                              rows.count.formatted(), name)
            }
            return String(format: String(localized: "search.layer.set.browse %@ %@",
                                         defaultValue: "%1$@ for %2$@"),
                          Self.resultsPhrase(count), name)
        }
    }

    /// The row's sentence: "Within 100 closest matches to “how did the embassy…”".
    var rowDescription: String {
        String(format: String(localized: "search.layer.base.within %@", defaultValue: "Within %@"),
               setDescription)
    }

    /// What VoiceOver reads for the row, and announces when the layer starts: "Searching within 100
    /// closest matches to “how did the embassy…”".
    var accessibilityLabel: String {
        String(format: String(localized: "search.layer.base.a11y %@", defaultValue: "Searching within %@"),
               setDescription)
    }

    /// The row's second line, or `nil`: what the base held that the layer leaves out. Rows Checklist
    /// Mode was hiding are not searched, and a Meaning hit in a volume that is not downloaded has no
    /// row to search; the row says so rather than letting a count quietly fall short.
    var leftOutDescription: String? {
        var parts: [String] = []
        if hiddenByChecklist > 0 {
            parts.append(CountCopy.phrase(
                hiddenByChecklist,
                one: String(localized: "search.layer.leftOut.reviewed.one",
                            defaultValue: "%@ result hidden as reviewed is not included."),
                many: String(localized: "search.layer.leftOut.reviewed.many",
                             defaultValue: "%@ results hidden as reviewed are not included.")))
        }
        if notDownloaded > 0 {
            parts.append(CountCopy.phrase(
                notDownloaded,
                one: String(localized: "search.layer.leftOut.notDownloaded.one",
                            defaultValue: "%@ match in a volume you have not downloaded is not included."),
                many: String(localized: "search.layer.leftOut.notDownloaded.many",
                             defaultValue: "%@ matches in volumes you have not downloaded are not included.")))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// The command that returns to the base from a layer that found nothing: "Back to the 100
    /// Matches", "Back to the 212 Results".
    var backTitle: String {
        let count = members.count
        switch kind {
        case .meaning:
            return count == 1
                ? String(localized: "search.layer.back.match", defaultValue: "Back to the Closest Match")
                : String(format: String(localized: "search.layer.back.matches %@",
                                        defaultValue: "Back to the %@ Matches"), count.formatted())
        case .keywords, .browse:
            return count == 1
                ? String(localized: "search.layer.back.result", defaultValue: "Back to the Result")
                : String(format: String(localized: "search.layer.back.results %@",
                                        defaultValue: "Back to the %@ Results"), count.formatted())
        }
    }

    /// The base as a capture names it, for a working corpus saved inside a layer: the question in
    /// quotation marks, the words in quotation marks, or a browse's name (``ResultSetScope/layerBaseLabel``).
    var captureLabel: String? {
        switch kind {
        case .meaning, .keywords:
            return shownQuery.isEmpty ? nil : "“\(shownQuery)”"
        case .browse(let name):
            return name
        }
    }

    // MARK: - The record

    /// The `base=` part a layer's trail row carries (#1577 lane 4): the base's kind, its members'
    /// count and its query, percent-encoded so that a `;` or `=` in the words cannot break the
    /// signature apart. Locale-free, as every part of a signature is. For a list ranked whole the
    /// count is its whole match's, less the rows hidden as reviewed (#1577 lane 6).
    ///
    /// `base=meaning:100:how%20did%20the%20embassy`, `base=keywords:212:offset%20agreement`,
    /// `base=browse:1976:Aerial%20reconnaissance`. `SearchScopeSignature.describe` turns it into a
    /// phrase; an earlier build passes over it, as it passes over any part it does not know.
    var signaturePart: String {
        let kindToken: String
        let text: String
        switch kind {
        case .meaning: kindToken = "meaning"; text = shownQuery
        case .keywords: kindToken = "keywords"; text = shownQuery
        case .browse(let name): kindToken = "browse"; text = name ?? ""
        }
        return "base=\(kindToken):\(recordedSize):\(Self.percentEncoded(text))"
    }

    /// The size the record gives the list: its members, or for a list ranked whole (#1577 lane 6) its whole match
    /// less the rows Checklist Mode hid, which is what a question ranked inside.
    private var recordedSize: Int {
        guard ranksWholeMatch, let whole = wholeMatchCount else { return members.count }
        return max(0, whole - hiddenByChecklist)
    }

    /// What a layer's rendered expression adds, for the method appendix's CSV, which prints the
    /// expression verbatim: the base, in the same three parts as ``signaturePart``.
    var renderedExpressionSuffix: String {
        "; " + signaturePart
    }

    /// Percent-encodes everything but the unreserved characters of RFC 3986, so the text survives
    /// inside a signature part whose separators are `;`, `=` and `:`, and the signature stays plain
    /// ASCII. `CharacterSet.alphanumerics` would let any letter through, an accented one included, in
    /// whichever Unicode form it was typed.
    static func percentEncoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// The characters a signature part keeps as they are: ASCII letters and digits, `-`, `.`, `_`, `~`.
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// "1 result" or "212 results", in the words the results header uses.
    private static func resultsPhrase(_ count: Int) -> String {
        count == 1
            ? String(localized: "search.count.one", defaultValue: "1 result")
            : String(format: String(localized: "search.count %@", defaultValue: "%@ results"), count.formatted())
    }
}

// MARK: - PinnedResultBase + holding a list

/// The rules a view model holds the list on screen by (#1577 lane 5). They were `SearchViewModel`'s own in lane 4;
/// here, the Mac's window holds a list by the same ones, and a test reads them with no view model: the Mac's is
/// compiled for the Mac alone, and no test runs it.
extension PinnedResultBase {

    /// The rows a layer over `rows` runs inside: those the list on screen shows, in the search's own order.
    ///
    /// `shown` is the list as the reader sees it (`displayedResults`): the rows less those Checklist Mode hides, in
    /// the order the sort menu gives them. The members keep the search's order instead, so that words found in a
    /// Meaning list come back closest first, and a ranking's unranked rows follow in the list's own order, whatever
    /// date order the list was in when it was held.
    ///
    /// - Parameters:
    ///   - rows: Every row the search loaded, in its order.
    ///   - shown: The rows the list shows.
    /// - Returns: The members.
    static func members(of rows: [SearchResult], shown: [SearchResult]) -> [SearchResult] {
        let shownIds = Set(shown.map(\.id))
        return rows.filter { shownIds.contains($0.id) }
    }

    /// What kind of list a base is held from, and the words that name it where none were typed.
    ///
    /// A Meaning list is a Meaning base, and a list found by typed words a keyword base. With nothing typed, a list
    /// found by a restored phrase or prefix is a keyword base all the same, named by those words (lane 4's review
    /// found it held as "your browse"); anything else is a browse, named by its filter.
    ///
    /// - Parameters:
    ///   - route: The route that produced the rows.
    ///   - query: The submitted words, trimmed.
    ///   - ran: The parameters the rows' keyword search ran with (``UserTagCountScope/ranParameters``), or `nil`.
    ///   - browseName: What a browse is of (``browseName(of:)``), or `nil` where it has no name.
    /// - Returns: The kind, and the words a list with nothing typed is named by.
    static func kind(route: ExecutedSearchRoute, query: String, ran: SearchParameters?,
                     browseName: String?) -> (kind: Kind, describedQuery: String?) {
        if route == .meaning { return (.meaning, nil) }
        guard query.isEmpty else { return (.keywords, nil) }
        if let words = describedWords(phrase: ran?.phrase, prefix: ran?.prefixWildcard) { return (.keywords, words) }
        return (.browse(name: browseName), nil)
    }

    /// What a browse with no words is of, for the row that names it as a held base: the person, the topic or the
    /// subject area its filter names, in that order, or `nil` when none has a name.
    ///
    /// - Parameter parameters: The browse's parameters.
    /// - Returns: The name, or `nil`.
    static func browseName(of parameters: SearchParameters) -> String? {
        let personRef = parameters.personRef?.trimmingCharacters(in: .whitespaces) ?? ""
        if parameters.personRollupId != nil || !personRef.isEmpty,
           let label = parameters.personLabel, !label.isEmpty {
            return label
        }
        if parameters.subjectRef != nil, let name = parameters.subjectName, !name.isEmpty { return name }
        let vocabulary = DocumentSubjectStore.shared?.bucketVocabulary
        if let bucket = parameters.subjectBucketKey.flatMap({ vocabulary?.id(forKey: $0) }) ?? parameters.subjectBucket {
            return vocabulary?.label(at: bucket)
        }
        return nil
    }

    /// Whether the filters of `parameters` narrow a layer beyond the held list, so that the header says the words
    /// "pass your filters" too (`ResultSetScope.layerFiltersNarrowed`): a filter is set, and the filters are not the
    /// ones the list was found under.
    ///
    /// A filter taken away since the list was held removes none of its rows, and the first condition says so where no
    /// filter is left. The comparison is with the run that found the list (``filterSignature``), not the fields:
    /// lane 4's review found a filter set in the sheet and never run taken for the list's own.
    ///
    /// - Parameter parameters: The filters the layer runs under, without the held list's gate.
    /// - Returns: Whether they narrow it.
    func filtersNarrow(_ parameters: SearchParameters) -> Bool {
        !wasFound(under: parameters) && Self.setsAFilter(parameters)
    }

    /// Whether the held list was found under the filters of `parameters`, its document set among them.
    ///
    /// The Mac's window applies a filter as it is set, so a filter changed while a list was held is one its rows were
    /// not found under: leaving the list then runs its search again, and puts it back with no search only when this
    /// holds (`MacSearchViewModel.leaveBase()`).
    ///
    /// - Parameter parameters: The filters in force, without the held list's gate.
    /// - Returns: Whether they are the list's own.
    func wasFound(under parameters: SearchParameters) -> Bool {
        SearchScopeSignature.signature(for: parameters) == filterSignature
    }

    /// Whether `parameters` filter a search at all: a topic, or anything the scope signature records away from its
    /// default, a document set, a scope toggle off and a document type among them. The same set as
    /// `SearchViewModel.hasActiveFilters`, read from a parameter value, which the Mac's window holds and iPhone and
    /// iPad build from their fields.
    ///
    /// - Parameter parameters: The parameters.
    /// - Returns: Whether any filter is set.
    static func setsAFilter(_ parameters: SearchParameters) -> Bool {
        parameters.subjectRef != nil
            || SearchScopeSignature.signature(for: parameters) != unfilteredSignature
    }

    /// The scope signature of a search with no filter set.
    private static let unfilteredSignature = SearchScopeSignature.signature(for: SearchParameters())
}

// MARK: - SearchLayerSwap

/// The held list and the search inside it, swapped (#1577 lane 7): the layer's words or question become a list of their
/// own, and the list's own words or question become the search inside it. The base row's Swap.
///
/// The two orders give different lists (the assessment's §9). Words found in a Meaning list are at most its hundred
/// closest, "7 of your 100 closest matches contain these words", where a question ranking the words' own results lists
/// every document that holds them, "212 results, closest first". Swap turns either into the other without retyping.
///
/// It runs what the reader would run by hand in the other order, and nothing besides: the layer's words or question
/// through its own engine, under the working corpus and the filters in force, as a search of its own; that list held,
/// as Search Within These Results holds one; and the held list's words or question inside it. So the list it shows is
/// the one built by hand in that order, a list cut at its ceiling ranked whole as lane 6 ranks one, and each of the two
/// searches writes a trail row of its own, as by hand. The checklist's marks are the held list's search's, and the new
/// list's search is a search of its own, which Checklist Mode treats as any search: other words start it over.
///
/// ## The trail's anchor is set aside
/// The layer's row is the one the trail writer last wrote, and the new list's search runs the layer's own words or
/// question, so the writer would take it for a re-run and rewrite the layer's row as a search across the library. The
/// held list's anchor, which leaving gives back, names the held list's words, which the swap then searches inside the
/// new list. So a view model sets the anchor aside before the swap's first search, as holding a list sets it aside
/// (rule 5), and every row written before the swap stays as it was.
///
/// ## What a swap needs
/// A layer's rows on screen, since there is nothing to swap before the field has run inside the list, and words or a
/// question on each side: a browse has none of its own (a person's mentions, a subject area), nor does a list found by a
/// restored phrase or prefix with nothing typed, whose words are a filter's and not the field's.
///
/// Version history:
///   1.0 — #1577 lane 7: initial implementation
struct SearchLayerSwap: Sendable {

    /// The list held when the swap began, which the row goes on naming until the new list is held, so that the row
    /// does not give way to the Keywords | Meaning control while the new list's search runs.
    let heldList: PinnedResultBase
    /// The way the search inside the new list runs: the other way from the held list's.
    let direction: SearchLayerDirection
    /// The words or question the new list is found by: the layer's, as it ran.
    let listQuery: String
    /// The words or question searched inside the new list: the held list's own.
    let layerQuery: String

    /// The engine the new list's own search runs through, which is the one the field ran inside the held list.
    var listEngine: SearchMode { direction.baseEngine }

    /// The swap of `heldList` and the layer on screen over it, or `nil` where none can be made.
    ///
    /// - Parameters:
    ///   - heldList: The held list.
    ///   - route: The route that produced the rows on screen: a layer's, or there is nothing to swap.
    ///   - layerQuery: The words or question the rows on screen ran with (the submitted query, not the live field).
    init?(heldList: PinnedResultBase, route: ExecutedSearchRoute, layerQuery: String) {
        let layer = layerQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let own = heldList.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard route.isLayer, !layer.isEmpty, !own.isEmpty else { return nil }
        self.heldList = heldList
        self.direction = heldList.direction.swapped
        self.listQuery = layer
        self.layerQuery = own
    }

    /// Whether the rows on screen are the new list's own search: a list its engine gives, found by its words or
    /// question. The swap holds that list and goes on; anything else on screen, a search the reader ran meanwhile or a
    /// hand-off's, ends it.
    ///
    /// - Parameters:
    ///   - route: The route that produced the rows on screen.
    ///   - query: The words or question those rows ran with.
    /// - Returns: Whether they are the new list.
    func isAnswered(by route: ExecutedSearchRoute, query: String) -> Bool {
        SearchLayerDirection.starting(over: route) == direction
            && query.trimmingCharacters(in: .whitespacesAndNewlines) == listQuery
    }
}

// MARK: - AnsweredSearchTrigger

/// A search the rows on screen already answer (#1577 lane 5), which the Mac's window then does not run.
///
/// The Mac's Search window runs a search whenever its trigger changes: the engine, the submitted words or the filters'
/// version. Leaving a held list puts back its engine and its words, which changes the trigger, though the list's own
/// rows are already back on screen from memory: run, the search would fetch them again, flash "Searching…" and, for a
/// Meaning list, encode the question again. So the view model records the trigger its restored rows answer, and the
/// search the window's task starts for it does nothing. Any other trigger, a filter edited before the task ran
/// included, is searched as always.
///
/// Version history:
///   1.0 — #1577 lane 5: initial implementation
struct AnsweredSearchTrigger: Equatable, Sendable {

    /// The trigger the rows on screen answer, until a search asks about it.
    private var trigger: String?

    /// Records that the rows on screen answer `trigger`.
    ///
    /// - Parameter trigger: The window's trigger as the rows were put back.
    mutating func answer(_ trigger: String) {
        self.trigger = trigger
    }

    /// Whether the rows on screen answer the search `trigger` asks for. True once, for the trigger answered last;
    /// asking about any trigger forgets the answer, so a later search of the same words runs.
    ///
    /// - Parameter trigger: The trigger of the search about to run.
    /// - Returns: Whether that search has nothing to do.
    mutating func consume(_ trigger: String) -> Bool {
        defer { self.trigger = nil }
        return self.trigger == trigger
    }
}

// MARK: - LayeredResultComposer

/// The pure steps of a layer (#1577 lane 4), shared by both search view models so the two cannot
/// order or gate a layer differently.
///
/// - A keyword layer's rows, put in the base's order with the base's scores.
/// - A ranking merged with the members it could not rank, which go last in the base's order.
/// - The gate a search runs with, the held base joining the working corpus and the History scope.
/// - Where a ranking's unranked rows begin in the list as shown.
///
/// Version history:
///   1.0 — #1577 lane 4: initial implementation
///   1.1 — #1577 lane 5: ``unrankedTail(of:route:sortOrder:)``, the iPhone view model's rule, which the Mac's window
///          follows too; ``gating(_:inside:)`` has its four Mac callers
///   1.2 — #1577 lane 6: a ranking of a list's whole match: the set it ranks (``wholeMatchSet(_:leavingOut:inside:)``,
///          inside the filters chosen since: ``wholeMatchSet(_:passing:)``), the rows it lists
///          (``wholeMatchSelection(ranked:members:admitted:limit:)``, ``admittedMembers(_:of:)``) and their scores
///          (``wholeMatchRows(ranked:fill:rows:)``)
enum LayeredResultComposer {

    /// The rows a keyword search inside a Meaning base found, in the base's order and each with the
    /// base's score (rule 1: words decide which documents are in the list, meaning their order).
    ///
    /// The keyword search ranks them by BM25, which inside a hundred documents says little, and the
    /// layer is "atop" the Meaning list, so its order is the list's. A row keeps its own snippet, which
    /// carries the words in bold, and gains the base's chip. A row the base does not hold cannot come
    /// from a search gated to it and is dropped; a row found twice is kept once.
    ///
    /// - Parameters:
    ///   - keywordRows: The keyword search's rows, in any order.
    ///   - base: The held Meaning list.
    /// - Returns: The rows, in the base's order.
    static func wordsInMatches(keywordRows: [SearchResult], base: PinnedResultBase) -> [SearchResult] {
        let found = Dictionary(keywordRows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let scores = base.scoreByKey
        return base.members.compactMap { member in
            guard let row = found[member.id] else { return nil }
            let score = scores[member.id]
            return row.replacingScores(bm25: score.map { -$0 } ?? row.bm25Score, semantic: score)
        }
    }

    /// A ranking of the base's members merged with the members it could not rank: the ranked ones
    /// closest first, each with its score, then the others in the base's order with none (rule 4: a
    /// document that cannot be ranked is shown last, never dropped and never scored as zero).
    ///
    /// Each row is the base's own, so it keeps its keyword snippet and its words in bold.
    ///
    /// - Parameters:
    ///   - ranked: The ranked members' keys and scores, closest first.
    ///   - members: The members, in the base's order.
    /// - Returns: The rows, and how many of them were not ranked.
    static func rankedWithTail(ranked: [(key: String, score: Double)],
                               members: [SearchResult]) -> (rows: [SearchResult], unranked: Int) {
        let byKey = Dictionary(members.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var placed: Set<String> = []
        var rows: [SearchResult] = []
        rows.reserveCapacity(members.count)
        for hit in ranked {
            guard let row = byKey[hit.key], placed.insert(hit.key).inserted else { continue }
            // The negated score, as a Meaning search's rows carry it, so every lower-is-better reader
            // (the date sorts' tie-break) orders ranked rows by closeness.
            rows.append(row.replacingScores(bm25: -hit.score, semantic: hit.score))
        }
        var unranked = 0
        for member in members where placed.insert(member.id).inserted {
            rows.append(member.replacingScores(bm25: member.bm25Score, semantic: nil))
            unranked += 1
        }
        return (rows, unranked)
    }

    /// The documents a ranking of a list's whole match ranks inside (#1577 lane 6): the match's keys, less the rows
    /// Checklist Mode hid when the list was held, inside the document gate a working corpus applied since sets.
    ///
    /// A list's members are its rows less the hidden ones, and a working corpus applied since narrows them (rule 2:
    /// filters edited during a layer only narrow it); the whole match is narrowed by the same two. Pure, and called
    /// off the main actor: a common word's match is some 200,000 keys.
    ///
    /// - Parameters:
    ///   - keys: The match's keys, as the index gave them.
    ///   - hidden: The keys of the rows hidden as reviewed when the list was held (`PinnedResultBase.hiddenKeys`).
    ///   - gate: The document gate in force outside the held list, or `nil` for none. An empty gate admits nothing,
    ///     as it does everywhere.
    /// - Returns: The keys, in the order given.
    static func wholeMatchSet(_ keys: [String], leavingOut hidden: Set<String>, inside gate: [String]?) -> [String] {
        let admitted = gate.map { Set($0) }
        guard !hidden.isEmpty || admitted != nil else { return keys }
        return keys.filter { !hidden.contains($0) && (admitted?.contains($0) ?? true) }
    }

    /// The documents of a whole match's set that pass the filters chosen since the list was held (#1577 lane 6), which
    /// is the set a ranking of the match ranks inside: so the closest it lists are the closest of those that pass, and a
    /// document that passes and ranks below the ceiling is not lost to the cut. Pure, and called off the main actor.
    ///
    /// - Parameters:
    ///   - set: The set (``wholeMatchSet(_:leavingOut:inside:)``).
    ///   - filterKeys: The keys the other filters admit (`SearchService.filterKeySet(parameters:)`), or `nil` where
    ///     nothing constrains.
    /// - Returns: The members that pass, in the set's order.
    static func wholeMatchSet(_ set: [String], passing filterKeys: Set<String>?) -> [String] {
        guard let filterKeys else { return set }
        return set.filter { filterKeys.contains($0) }
    }

    /// The rows a ranking of a whole match lists, chosen before they are fetched (#1577 lane 6): the ranked documents,
    /// closest first, at most `limit`; then, where fewer than `limit` could be ranked, the held list's own members that
    /// could not be, in the list's order, up to `limit` in all.
    ///
    /// Rule 4 as far as the ceiling allows: a document no ranking can place is listed after those it ranked, never
    /// scored as zero, and those the list has no room for are counted (`WholeMatchRanking.notRanked`). The members are
    /// the keyword search's highest-scoring rows, so the unranked among them, in their order, are the unranked
    /// documents that search puts first, and a ranking with nothing it can score lists the held list's own rows. When
    /// fewer than `limit` are ranked, `ranked` holds every document that was, so a member not among them is one that
    /// could not be.
    ///
    /// - Parameters:
    ///   - ranked: The ranked documents' keys and scores, closest first, at most `limit`: the searcher's hits.
    ///   - members: The held list's members, in its order.
    ///   - admitted: The members' keys that are in the set ranked (``admittedMembers(_:of:)``): a member a working
    ///     corpus applied since leaves out, or one the match no longer holds, is not listed.
    ///   - limit: The ceiling.
    /// - Returns: The ranked documents to list, and the members to list after them.
    static func wholeMatchSelection(ranked: [(key: String, score: Double)], members: [SearchResult],
                                    admitted: Set<String>, limit: Int)
        -> (ranked: [(key: String, score: Double)], fill: [SearchResult]) {
        let chosen = Array(ranked.prefix(max(0, limit)))
        let room = max(0, limit) - chosen.count
        guard room > 0 else { return (chosen, []) }
        let placed = Set(chosen.map(\.key))
        let fill = members.lazy
            .filter { !placed.contains($0.id) && admitted.contains($0.id) }
            .prefix(room)
        return (chosen, Array(fill))
    }

    /// The keys of the held list's members that are in the set a ranking of its whole match ranks (#1577 lane 6): the
    /// rows it may list after the ranked ones (``wholeMatchSelection(ranked:members:admitted:limit:)``). Pure, and called
    /// off the main actor with ``wholeMatchSet(_:leavingOut:inside:)``, since the set is some 200,000 keys.
    ///
    /// - Parameters:
    ///   - members: The held list's members.
    ///   - set: The set ranked.
    /// - Returns: The members' keys in it.
    static func admittedMembers(_ members: [SearchResult], of set: [String]) -> Set<String> {
        let keys = Set(members.map(\.id))
        var admitted: Set<String> = []
        for key in set where keys.contains(key) {
            admitted.insert(key)
            if admitted.count == keys.count { break }
        }
        return admitted
    }

    /// A whole match's chosen rows with their scores (#1577 lane 6): each ranked document's row, closest first, with
    /// its score on the chip and negated for the date sorts' tie-break, as a Meaning list's rows carry it; then the
    /// members listed after them, with none.
    ///
    /// - Parameters:
    ///   - ranked: The ranked documents to list, closest first.
    ///   - fill: The members to list after them, in the list's order.
    ///   - rows: A row for each ranked document: the held list's own, or the keyword search's run again for those it
    ///     does not hold, so each keeps its keyword snippet.
    /// - Returns: The rows, and how many ranked documents had no row, which are not listed.
    static func wholeMatchRows(ranked: [(key: String, score: Double)], fill: [SearchResult],
                               rows: [String: SearchResult]) -> (rows: [SearchResult], missing: Int) {
        var listed: [SearchResult] = []
        listed.reserveCapacity(ranked.count + fill.count)
        var missing = 0
        for hit in ranked {
            guard let row = rows[hit.key] else {
                missing += 1
                continue
            }
            listed.append(row.replacingScores(bm25: -hit.score, semantic: hit.score))
        }
        for member in fill {
            listed.append(member.replacingScores(bm25: member.bm25Score, semantic: nil))
        }
        return (listed, missing)
    }

    /// `parameters` gated to the base as well: its document set joins the working corpus and the
    /// History scope already there (``DocumentScopeGate/combine(corpus:projectGate:pin:)``). With no
    /// base the value is returned unchanged.
    ///
    /// The one place a held base enters the value a search runs with, on both platforms, so that
    /// the parameters stored for the filter summary and the token caption on the Mac never hold it
    /// (rule 3: the pin is a scope, not a filter).
    ///
    /// - Parameters:
    ///   - parameters: The parameters the next search would run with.
    ///   - base: The held base, or `nil`.
    /// - Returns: The parameters a search inside the base runs with.
    static func gating(_ parameters: SearchParameters, inside base: PinnedResultBase?) -> SearchParameters {
        guard let base else { return parameters }
        var gated = parameters
        gated.documentIds = DocumentScopeGate.combine(corpus: parameters.documentIds,
                                                      projectGate: nil,
                                                      pin: base.memberKeys)
        return gated
    }

    /// Where a ranking's unranked rows begin in the list as shown, and how many it shows: the line that counts them
    /// goes above the first (rule 4). `nil` outside a ranking of a held list, with every row ranked, and under a date
    /// order, where the unranked rows are no longer together at the end.
    ///
    /// - Parameters:
    ///   - shown: The list as shown (`displayedResults`).
    ///   - route: The route that produced the rows.
    ///   - sortOrder: The order the list is shown in.
    /// - Returns: The first unranked row's key and the count, or `nil`.
    static func unrankedTail(of shown: [SearchResult], route: ExecutedSearchRoute,
                             sortOrder: SearchSortOrder) -> (firstId: String, count: Int)? {
        guard case .rankedByMeaning = route, sortOrder == .relevance else { return nil }
        let unranked = shown.filter { $0.semanticScore == nil }
        guard let first = unranked.first else { return nil }
        return (first.id, unranked.count)
    }
}

// MARK: - ExecutedSearchRoute + layers

extension ExecutedSearchRoute {

    /// Whether these rows are a layer's: words found in a held Meaning list, or a held list ranked by
    /// a question (#1577 lane 4).
    var isLayer: Bool {
        switch self {
        case .keywords, .meaning: return false
        case .wordsInMatches, .rankedByMeaning: return true
        }
    }
}

// MARK: - ResultSetScope + layers

extension ResultSetScope {

    /// This scope with what a layer's sentences owe, from the held list and the layer's run (#1577 lanes 4 and 5).
    /// The one place either view model says them, so that the Mac's window, which no test runs, says what the iPhone's
    /// tested view model says.
    ///
    /// - Words found in a list, and a ranking: whether filters chosen since narrow them
    ///   (``layerFiltersNarrowed``), and the list a capture names beside the layer's text (``layerBaseLabel``).
    /// - A ranking: whether the list was cut at its fetch (``layerBaseWasCut``), and the rows the checklist hid when it
    ///   was held (``layerBaseHiddenByChecklist``). A ranking's rows can be fewer than its list's with nothing cut:
    ///   those the checklist hid, and those a filter chosen since removes (lane 4's review).
    /// - Every route: whether the list is in its own order (``listIsInRankOrder``), which only a ranking's header reads.
    ///
    /// - Parameters:
    ///   - base: The held list, or `nil`.
    ///   - filtersNarrowed: Whether filters narrowed the last layer, as its run recorded
    ///     (`PinnedResultBase.filtersNarrow(_:)`).
    ///   - sortOrder: The order the list is shown in.
    /// - Returns: The scope.
    func describingLayer(over base: PinnedResultBase?, filtersNarrowed: Bool,
                         sortOrder: SearchSortOrder) -> ResultSetScope {
        var scope = self
        var ranking = false
        if case .rankedByMeaning = route { ranking = true }
        scope.layerFiltersNarrowed = route.isLayer && filtersNarrowed
        scope.listIsInRankOrder = sortOrder == .relevance
        scope.layerBaseLabel = route.isLayer ? base?.captureLabel : nil
        scope.layerBaseWasCut = ranking ? base?.wasCut : nil
        scope.layerBaseHiddenByChecklist = ranking ? base?.hiddenByChecklist ?? 0 : 0
        return scope
    }
}

// MARK: - UserTagCountScope + the run

extension UserTagCountScope {

    /// The parameters a keyword search ran with, where these counts are over its match; `nil` for counts over result
    /// keys, a Meaning list's (#1577 lane 5). What a held list's kind and name are read from.
    var ranParameters: SearchParameters? {
        if case .match(let parameters) = self { return parameters }
        return nil
    }
}

// MARK: - SearchResult + scores

extension SearchResult {

    /// This result with other scores and nothing else changed (#1577 lane 4): a layer moves a row's
    /// chip and its place in a ranking, and keeps its snippet, its words in bold and its tags.
    ///
    /// - Parameters:
    ///   - bm25: The lower-is-better score the date sorts break ties by.
    ///   - semantic: The Meaning score the chip shows, or `nil` for none.
    /// - Returns: The row.
    func replacingScores(bm25: Double, semantic: Double?) -> SearchResult {
        SearchResult(
            documentId: documentId,
            volumeId: volumeId,
            documentNumber: documentNumber,
            header: header,
            dateline: dateline,
            dateISO: dateISO,
            sourceNote: sourceNote,
            snippet: snippet,
            bm25Score: bm25,
            semanticScore: semantic,
            subjectTagIds: subjectTagIds,
            userTagIds: userTagIds,
            isEditorialNote: isEditorialNote,
            isFrontMatter: isFrontMatter)
    }
}
