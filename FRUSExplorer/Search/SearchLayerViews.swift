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

import SwiftUI

// MARK: - SearchLayerBaseRow

/// The row that names a held base while a layer runs inside it (#1577 lane 4).
///
/// It takes the Keywords | Meaning control's place in the search screen's top inset, so the inset
/// does not gain a row: while a base is held the field runs the other engine and the control has
/// nothing to choose. One element for VoiceOver, "Searching within 100 closest matches to …", with its
/// close button as a child, "Stop searching within these results". The button keeps a 44-point target.
///
/// At the accessibility sizes it stays near the height of the control it replaces: its text is drawn at
/// XXXL, the largest standard size, in two lines at most, without the second line, and a touch and hold
/// shows the whole of both in the Large Content Viewer (VoiceOver reads both at every size). Grown to AX5
/// the sentence took three lines of 52 points on an iPhone 17, more than the inset has: SwiftUI centred
/// the inset, which put the row above the screen and the list's first row below it; and capped at AX1, as
/// the selection bar is, it still took three lines on an iPhone SE, and left no room for a result above
/// the tab shell's banner (`SearchLayerBaseRowFitTests`, 2026-10-17).
///
/// The sentences are ``PinnedResultBase``'s, so that a test can read them with no view.
///
/// Version history:
///   1.0 — #1577 lane 4: initial implementation
struct SearchLayerBaseRow: View {

    /// The held base.
    let base: PinnedResultBase
    /// Leaves the base: its rows come back, with no search.
    let leave: () -> Void

    /// The reader's text size, before the row's own cap: whether the row is drawn compact.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let compact = dynamicTypeSize.isAccessibilitySize
        HStack(alignment: .center, spacing: 8) {
            // The Meaning feature's glyph for a Meaning list, as the strip and the model offer use it.
            Image(systemName: base.kind == .meaning ? SemanticGlyph.feature : "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(base.rowDescription)
                    .font(.footnote)
                    .lineLimit(compact ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
                if !compact, let leftOut = base.leftOutDescription {
                    Text(leftOut)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([base.accessibilityLabel, base.leftOutDescription]
                .compactMap { $0 }.joined(separator: ". "))
            .accessibilityShowsLargeContentViewer {
                Label([base.rowDescription, base.leftOutDescription].compactMap { $0 }.joined(separator: " "),
                      systemImage: base.kind == .meaning ? SemanticGlyph.feature : "magnifyingglass")
            }
            .accessibilityIdentifier("search.layer.base")
            Button(action: leave) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .controlHelp(
                String(localized: "search.layer.leave.a11y", defaultValue: "Stop searching within these results"),
                detail: String(localized: "search.layer.leave.help",
                               defaultValue: "Show the list you were searching within again, as it was"),
                systemImage: "xmark.circle.fill")
            .accessibilityIdentifier("search.layer.leave")
        }
        .padding(.leading)
        .padding(.trailing, 6)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background(.bar)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - SearchLayerEmptyState

/// What the results area shows when a layer finds nothing (#1577 lane 4): what it looked in, and the
/// ways on from there.
///
/// Neither the keyword zero-state nor the corpus-wide Meaning fallback is shown while a base is held
/// (rule 7): the first diagnoses a term's absence across the library, and the second ignores every
/// filter and answers a different question. Words found nowhere in a Meaning list can be searched for
/// across the whole library, which leaves the base; or the reader goes back to the list.
///
/// Version history:
///   1.0 — #1577 lane 4: initial implementation
struct SearchLayerEmptyState: View {

    /// What the layer looked in, and that it found nothing: the results header's sentence.
    let statement: String
    /// The command that searches the whole library for the layer's words, or `nil` where the layer
    /// was a ranking, whose question is no keyword search.
    let searchLibraryTitle: String?
    /// The command that goes back to the held list ("Back to the 100 Matches").
    let backTitle: String
    /// Leaves the base and runs the words across the library.
    let searchLibrary: () -> Void
    /// Leaves the base, putting its rows back.
    let back: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 40

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: FRUSTheme.cappedGlyphSize(glyphSize, base: 40)))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Text(statement)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("search.layer.empty.statement")
                if let searchLibraryTitle {
                    Button(searchLibraryTitle, action: searchLibrary)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("search.layer.empty.searchLibrary")
                }
                Button(backTitle, action: back)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("search.layer.empty.back")
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// "Search the Whole Library for These Words": the empty state's command for words found nowhere
    /// in a Meaning list.
    static var searchLibraryTitle: String {
        String(localized: "search.layer.empty.searchLibrary", defaultValue: "Search the Whole Library for These Words")
    }

    /// What an empty ranking says. A ranking returns its whole list, so it is empty only when the
    /// filters, or a working corpus applied since, removed every member.
    static var rankedStatement: String {
        String(localized: "search.layer.empty.ranked",
               defaultValue: "None of the results you are searching within passes your filters.")
    }
}

// MARK: - SearchLayerCopy

/// The search screen's other words for a layer (#1577 lane 4), apart from the views so that a test can
/// read them.
///
/// Version history:
///   1.0 — #1577 lane 4: initial implementation
///   1.1 — #1577 lane 5: the Mac window's toolbar button and the label in the Keywords | Meaning control's place
enum SearchLayerCopy {

    /// The Sort menu's way into a ranking, on a keyword list: it is an order, as the menu's others are.
    static var closestToAQuestion: String {
        String(localized: "search.layer.sort.closestToQuestion", defaultValue: "Closest to a Question…")
    }

    /// Save this search's second line while a base is held, when the command is off: a layered search
    /// is not saved (the owner's decision 4), and the durable form is the result set.
    static var saveSearchUnavailable: String {
        String(localized: "search.saveSearch.layered",
               defaultValue: "Not while searching within results. Save as Working Corpus keeps these results.")
    }

    /// What VoiceOver hears when the reader leaves a base.
    static var leftAnnouncement: String {
        String(localized: "search.layer.announce.leave",
               defaultValue: "Stopped searching within these results")
    }

    /// The line over the rows a ranking could not rank, which follow the ranked ones (rule 4).
    ///
    /// - Parameter count: How many rows were not ranked.
    /// - Returns: The line.
    static func unrankedHeader(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "search.layer.unranked.one",
                                     defaultValue: "%@ result not ranked by meaning"),
                         many: String(localized: "search.layer.unranked.many",
                                      defaultValue: "%@ results not ranked by meaning"))
    }

    // MARK: The Mac's window (#1577 lane 5)

    /// The Mac Search window's toolbar button that holds the list on screen. Titled, as its neighbours are, and the
    /// same whichever way the layer will run, since a toolbar button's title is its place; its help says which.
    static var searchWithinResults: String {
        String(localized: "search.layer.toolbar", defaultValue: "Search Within Results")
    }

    /// The toolbar button's help: what it will do with the list on screen, or why it does nothing now.
    ///
    /// - Parameters:
    ///   - direction: The way a layer over the list on screen would run, or `nil` when none can start.
    ///   - isHolding: Whether a list is held already, which is one reason none can start.
    /// - Returns: The help.
    static func searchWithinResultsHelp(_ direction: SearchLayerDirection?, isHolding: Bool) -> String {
        if isHolding {
            return String(localized: "search.layer.toolbar.help.held",
                          defaultValue: "You are searching within results already. Stop searching within them to hold another list.")
        }
        switch direction {
        case .wordsInMatches?:
            return String(localized: "search.layer.toolbar.help.wordsInMatches",
                          defaultValue: "Find words in these closest matches. They keep their order, and only those that contain your words stay listed.")
        case .rankByMeaning?:
            return String(localized: "search.layer.toolbar.help.rankByMeaning",
                          defaultValue: "Rank these results by a question. Every result stays listed, the closest first.")
        case nil:
            return String(localized: "search.layer.toolbar.help.unavailable",
                          defaultValue: "Hold the list on screen and search inside it with the other engine: words in a Meaning search’s matches, or a question over keyword results.")
        }
    }

    /// The help of the plain label that takes the Keywords | Meaning control's place on the Mac while a list is held:
    /// a disabled control explains nothing, and the field runs one engine only inside a held list (the owner's
    /// decision 5).
    ///
    /// - Parameter engine: The engine the field runs inside the held list.
    /// - Returns: The help.
    static func heldEngineHelp(_ engine: SearchMode) -> String {
        String(format: String(localized: "search.layer.engine.help %@",
                              defaultValue: "While you search within results, the field searches by %@. Stop searching within them to choose the engine again."),
               engine.label)
    }
}
