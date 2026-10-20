// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SearchResultAccessibility

/// What VoiceOver says of a search result on iPhone and iPad, and what it offers there (#1684).
///
/// The row is one button, so it is one accessibility element, and its label replaces everything the
/// row draws. Until #1684 that label was the heading alone: VoiceOver said nothing of the number the
/// row draws beside the heading, the dateline, the volume, the classification chip, the badges or the
/// tags, and the tag chips, buttons inside the row's button, could not be reached to filter by.
///
/// ## The owner's choices (plan of record decision 73, 2026-10-19)
/// - **The label is the heading, then the row as it is drawn** (``label(for:tags:)``): the number
///   where the row draws one, the heading, the dateline, the volume id as printed, the classification
///   chip's own words, the Editorial Note and Front Matter badges, and the tags' names, joined by
///   commas. A Meaning search's score stays the row's value (#1577 lane 3), read after the label.
/// - **The snippet is offered on request**, as VoiceOver's More Content, and is not read when a
///   reader lands on the row (``moreContent(for:)``). The stored snippet runs to about 2,000
///   characters, where the row draws two lines of it by default.
/// - **Each tag is an action as well**, Filter by …, which does what a tap on its chip does
///   (``filterAction(tagName:)``).
///
/// The Mac's rows are not one element: each part is a text of its own, which VoiceOver reads, and a
/// Mac row's tag chips filter nothing for anyone. So none of this is the Mac's.
///
/// Version history:
///   1.0 — #1684: initial implementation
enum SearchResultAccessibility {

    // MARK: The label

    /// The row's accessibility label: the heading, then the row as it is drawn, top to bottom.
    ///
    /// The snippet and the score are not in it: the snippet is ``moreContent(for:)``'s, and the score
    /// is the row's accessibility value. A part the row does not draw is not said.
    ///
    /// - Parameters:
    ///   - result: The row's result.
    ///   - tags: The row's tag chips, as `UserTag.chips(for:among:)` lists them.
    /// - Returns: The label, its parts joined by commas.
    static func label(for result: SearchResult, tags: [UserTagChip]) -> String {
        var parts = [heading(for: result)]
        if let dateline = result.dateline { parts.append(dateline) }
        parts.append(result.volumeId)
        if let note = result.sourceNote,
           let marking = SourceNoteParser.classificationMarking(fromSourceNote: note) {
            parts.append(ClassificationChip.accessibilityLabel(for: marking))
        }
        if result.isEditorialNote { parts.append(editorialNoteBadge) }
        if result.isFrontMatter { parts.append(frontMatterBadge) }
        if !tags.isEmpty { parts.append(tagList(tags.map(\.name))) }
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// The heading as the row draws it, after the number the row draws beside it: "41. Minutes of the
    /// 507th Meeting…" whether the volume printed the number in the head or the row adds it.
    ///
    /// The row withholds its number when the head already opens with it
    /// (`DocumentHeaderDisplay.headerRepeatsNumber(_:number:)`), so neither form says it twice.
    ///
    /// - Parameter result: The row's result.
    /// - Returns: The number and heading.
    static func heading(for result: SearchResult) -> String {
        let heading = DocumentHeaderDisplay.trimmedHeader(result.header)
        guard let number = result.documentNumber, !number.isEmpty,
              !DocumentHeaderDisplay.headerRepeatsNumber(result.header, number: number) else { return heading }
        return String(format: String(localized: "search.result.a11y.numbered %@ %@",
                                     defaultValue: "%1$@. %2$@"),
                      number, heading)
    }

    /// The Editorial Note badge's words, which the row draws and its label says.
    static var editorialNoteBadge: String {
        String(localized: "search.result.editorialNote.badge", defaultValue: "Editorial Note")
    }

    /// The Front Matter badge's words, which the row draws and its label says.
    static var frontMatterBadge: String {
        String(localized: "search.result.frontMatter.badge", defaultValue: "Front Matter")
    }

    /// The label's last part, the row's tags by name: "Tags: Cuba, Berlin".
    ///
    /// - Parameter names: The tags' names, in the order the row draws their chips.
    /// - Returns: The part.
    static func tagList(_ names: [String]) -> String {
        String(format: String(localized: "search.result.a11y.tags %@", defaultValue: "Tags: %@"),
               names.joined(separator: ", "))
    }

    // MARK: The actions

    /// The name of the row's action for a tag, which filters the search by it as a tap on its chip
    /// does. It is also the chip's own label.
    ///
    /// - Parameter tagName: The tag's name.
    /// - Returns: "Filter by Cuba".
    static func filterAction(tagName: String) -> String {
        String(localized: "search.tagchip.a11y", defaultValue: "Filter by \(tagName)")
    }

    // MARK: More Content

    /// What the row offers as VoiceOver's More Content: a name, and the text.
    struct MoreContent: Equatable {
        /// The name VoiceOver says before the text: "Matched text" or "Opening text".
        let label: String
        /// The text.
        let text: String
    }

    /// About how many characters of the snippet More Content offers on each side of the matched
    /// word: about 300 in all, some fifty words.
    static let matchRadius = 150

    /// The row's More Content, or `nil` when it has none to offer.
    ///
    /// - **A keyword search marks the word it matched**, and More Content is the words around it
    ///   (``matchedText(inSnippet:radius:)``), "Matched text".
    /// - **A search whose words the body does not hold, or a search by filters alone, shows the
    ///   heading and dateline again** in the snippet's place (``isHeadingAndDatelineAgain(_:)``). The
    ///   label has read both, so More Content offers nothing, though a ranking of such a list gives the
    ///   row a score.
    /// - **A Meaning search marks no word.** Its snippet is the document's opening prose, after the
    ///   heading, source note and dateline (`ProseSnippet`), and More Content is that, "Opening text".
    ///   A row with no score and no mark is the case above, so the score is what says a row is one.
    ///
    /// - Parameter result: The row's result.
    /// - Returns: The content, or `nil`.
    static func moreContent(for result: SearchResult) -> MoreContent? {
        if let matched = matchedText(inSnippet: result.snippet) {
            return MoreContent(label: String(localized: "search.result.a11y.matchedText",
                                             defaultValue: "Matched text"),
                               text: matched)
        }
        guard result.semanticScore != nil, !isHeadingAndDatelineAgain(result) else { return nil }
        let opening = cut(collapsed(unmarked(result.snippet)), to: 2 * matchRadius)
        guard !opening.isEmpty else { return nil }
        return MoreContent(label: String(localized: "search.result.a11y.openingText",
                                         defaultValue: "Opening text"),
                           text: opening)
    }

    /// Whether a row's snippet is only its heading and dateline again: what `SearchService` shows when
    /// it has no words to mark in the body, its heading and dateline joined by " · " (the kit's private
    /// `headerFallbackSnippet`). A ranking keeps that snippet and adds a score
    /// (`SearchResult.replacingScores`), so the score alone does not tell it from a Meaning row's prose.
    /// `UITestSpokenVolumeSeederTests` reads the form from the service itself.
    ///
    /// - Parameter result: The row's result.
    /// - Returns: `true` when the snippet says nothing the label does not.
    static func isHeadingAndDatelineAgain(_ result: SearchResult) -> Bool {
        let parts = [result.header, result.dateline].compactMap { part -> String? in
            guard let part, !part.isEmpty else { return nil }
            return part
        }
        return result.snippet == parts.joined(separator: " · ")
    }

    /// The words around the word a keyword snippet marks, with the marks taken out: about `radius`
    /// characters on each side, cut at a space and marked "…" where cut, and every run of white
    /// space read as one space.
    ///
    /// The snippet's own "… " and " …" stay where the window reaches the snippet's ends.
    ///
    /// - Parameters:
    ///   - snippet: A snippet, with its match between `<b>` and `</b>`.
    ///   - radius: About how many characters to keep on each side of the match.
    /// - Returns: The words, or `nil` when the snippet marks no word.
    static func matchedText(inSnippet snippet: String, radius: Int = matchRadius) -> String? {
        guard let open = snippet.range(of: "<b>"),
              let close = snippet.range(of: "</b>", range: open.upperBound..<snippet.endIndex) else { return nil }
        let match = collapsed(unmarked(String(snippet[open.upperBound..<close.lowerBound])))
        guard !match.isEmpty else { return nil }
        let before = endOf(collapsed(unmarked(String(snippet[..<open.lowerBound]))), radius: radius)
        let after = cut(collapsed(unmarked(String(snippet[close.upperBound...]))), to: radius)
        // Collapsing trimmed the space on either side of the match, so it is put back where the
        // snippet had one; a match against punctuation ("(Rusk)") stays against it.
        let spaceBefore = !before.isEmpty && snippet[..<open.lowerBound].last?.isWhitespace == true
        let spaceAfter = !after.isEmpty && snippet[close.upperBound...].first?.isWhitespace == true
        return before + (spaceBefore ? " " : "") + match + (spaceAfter ? " " : "") + after
    }

    /// `text` with every `<b>` and `</b>` taken out.
    private static func unmarked(_ text: String) -> String {
        text.replacingOccurrences(of: "<b>", with: "").replacingOccurrences(of: "</b>", with: "")
    }

    /// `text` with every run of white space as one space, and none at either end.
    private static func collapsed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The start of `text`, about `limit` characters of it: the whole words inside them, marked
    /// " …" where cut.
    private static func cut(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let end = text.index(text.startIndex, offsetBy: limit)
        // The character after the window is a space: every word inside it is whole.
        if text[end] == " " { return String(text[..<end]) + " …" }
        guard let space = text[..<end].lastIndex(of: " ") else { return String(text[..<end]) + " …" }
        return String(text[..<space]) + " …"
    }

    /// The end of `text`, about `limit` characters of it: the whole words inside them, marked "… "
    /// where cut.
    private static func endOf(_ text: String, radius limit: Int) -> String {
        guard text.count > limit else { return text }
        let start = text.index(text.endIndex, offsetBy: -limit)
        // The character before the window is a space: every word inside it is whole.
        if text[text.index(before: start)] == " " { return "… " + String(text[start...]) }
        guard let space = text[start...].firstIndex(of: " ") else { return "… " + String(text[start...]) }
        return "… " + String(text[text.index(after: space)...])
    }
}
