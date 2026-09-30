// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CountCopy

/// A count and its noun in one phrase — grouped, and singular at exactly one (#1374).
///
/// ## Why one helper
/// The app ships no String Catalog and no `.stringsdict`, so nothing makes `"… volumes"` singular:
/// a count interpolated into it reads "1 volumes" for the commonest count there is. And the two
/// shapes the tree used for a count disagreed about grouping. `String(localized:defaultValue:)`
/// with `"\(n) docs"` formats `n` for the locale and prints `194,834 docs`;
/// `String(format: String(localized: …, defaultValue: "%lld docs"), n)` goes through
/// `String(format:)` with no locale and prints `17606 docs` — two screens apart on the Archives
/// axis. `HubCopy` and `NotesPaneSnapshot.noteCount` had fixed the singular with two keys and
/// kept the `%lld`, which was harmless only while their counts stopped below 1,000.
///
/// `phrase(_:one:many:locale:)` does both in one call: it picks the form by the count and hands
/// the form the count already formatted, as a `%@`. The forms are ordinary
/// `String(localized:defaultValue:)` strings with a `%@` where the number goes, so each keeps its
/// own key and its own place in `Docs/EditableContent.md`.
///
/// ## What it is not for
/// A **year** is not a count and must never go through here: "1,961" is the defect #1382 fixed.
/// Years are wrapped in `String(_:)`, which `CodingStandardsAuditTests`' year scan enforces.
///
/// `CodingStandardsAuditTests`' count scan refuses a `%lld` or an interpolation placed before a
/// countable noun — or a `(s)`-hedged word, a runtime `%@` noun, or `of them` — in a `defaultValue:`
/// or a SwiftUI text literal, against a baseline that may only shrink; this is the form that passes
/// it.
///
/// Version history:
///   1.0 — 2026-09-25: #1374, #1382 and #1422 — the shared count phrase
enum CountCopy {

    /// "1 document" / "12,067 documents": `count` formatted for `locale` and placed in `one` when it
    /// is exactly 1, in `many` otherwise (0 included, which English writes as a plural).
    ///
    /// - Parameters:
    ///   - count: How many.
    ///   - one: The singular form, with `%@` where the number goes — `"%@ document"`.
    ///   - many: The plural form, with `%@` where the number goes — `"%@ documents"`.
    ///   - locale: The locale that groups the number; the user's own unless a test passes one.
    /// - Returns: The phrase.
    static func phrase(_ count: Int, one: String, many: String,
                       locale: Locale = .autoupdatingCurrent) -> String {
        String(format: count == 1 ? one : many, count.formatted(.number.locale(locale)))
    }

    /// "1 document" / "N documents" — the phrase most of the app's counts are.
    ///
    /// - Parameters:
    ///   - count: How many documents.
    ///   - locale: The locale that groups the number.
    /// - Returns: The phrase.
    static func documents(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        phrase(count,
               one: String(localized: "count.documents.one", defaultValue: "%@ document"),
               many: String(localized: "count.documents.many", defaultValue: "%@ documents"),
               locale: locale)
    }

    /// "1 volume" / "N volumes".
    ///
    /// - Parameters:
    ///   - count: How many volumes.
    ///   - locale: The locale that groups the number.
    /// - Returns: The phrase.
    static func volumes(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        phrase(count,
               one: String(localized: "count.volumes.one", defaultValue: "%@ volume"),
               many: String(localized: "count.volumes.many", defaultValue: "%@ volumes"),
               locale: locale)
    }

    /// "1 doc" / "N docs" — the abbreviation the compact Browse and Archives rows use.
    ///
    /// - Parameters:
    ///   - count: How many documents.
    ///   - locale: The locale that groups the number.
    /// - Returns: The phrase.
    static func docs(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        phrase(count,
               one: String(localized: "count.docs.one", defaultValue: "%@ doc"),
               many: String(localized: "count.docs.many", defaultValue: "%@ docs"),
               locale: locale)
    }

    /// "1 vol" / "N vols" — the abbreviation beside `docs(_:locale:)`.
    ///
    /// - Parameters:
    ///   - count: How many volumes.
    ///   - locale: The locale that groups the number.
    /// - Returns: The phrase.
    static func vols(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        phrase(count,
               one: String(localized: "count.vols.one", defaultValue: "%@ vol"),
               many: String(localized: "count.vols.many", defaultValue: "%@ vols"),
               locale: locale)
    }
}

// MARK: - StatusBarCopy

/// The Mac status bar's indexing counts (#1478): "Indexed … · 1,204 docs · 1 person · 78 links".
///
/// The bar itself is Mac-only (`SupportingViews.swift`), and it built these as plain Swift strings,
/// `"\(meta.totalDocuments) docs"`, which no copy scan reads: ungrouped, unlocalized and never
/// singular ("1 persons"). They live here, in a file both platforms compile, so the iOS test host can
/// drive the same functions the Mac bar calls.
///
/// Version history:
///   1.0 — 2026-09-30: #1478
enum StatusBarCopy {

    /// The post-index line: "Indexed <title>", then each non-zero count.
    ///
    /// - Parameters:
    ///   - title: The volume's title.
    ///   - documents: Documents indexed.
    ///   - persons: Distinct people mentioned.
    ///   - links: Cross-references found.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    /// - Returns: The line, its parts joined by middle dots.
    static func indexedSummary(title: String, documents: Int, persons: Int, links: Int,
                               locale: Locale = .autoupdatingCurrent) -> String {
        let head = String(format: String(localized: "statusBar.indexed %@", defaultValue: "Indexed %@"), title)
        let parts = [documents > 0 ? CountCopy.docs(documents, locale: locale) : nil]
            + counts(persons: persons, links: links, locale: locale)
        let stats = parts.compactMap { $0 }
        return stats.isEmpty ? head : ([head] + stats).joined(separator: " · ")
    }

    /// The in-progress line's detail: people, links, and how many documents carry a date.
    ///
    /// - Parameters:
    ///   - persons: Distinct people mentioned so far.
    ///   - links: Cross-references found so far.
    ///   - dated: Documents carrying a parseable date.
    ///   - total: Documents in the volume.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    /// - Returns: The detail, its parts joined by middle dots; empty when every count is zero.
    static func metaSummary(persons: Int, links: Int, dated: Int, total: Int,
                            locale: Locale = .autoupdatingCurrent) -> String {
        var parts = counts(persons: persons, links: links, locale: locale).compactMap { $0 }
        if dated > 0 {
            parts.append(String(format: String(localized: "statusBar.dated %@ %@", defaultValue: "%1$@/%2$@ dated"),
                                dated.formatted(.number.locale(locale)),
                                total.formatted(.number.locale(locale))))
        }
        return parts.joined(separator: " · ")
    }

    /// The people and link phrases, `nil` where the count is zero.
    private static func counts(persons: Int, links: Int, locale: Locale) -> [String?] {
        [persons > 0
            ? CountCopy.phrase(persons,
                               one: String(localized: "statusBar.persons.one", defaultValue: "%@ person"),
                               many: String(localized: "statusBar.persons.many", defaultValue: "%@ persons"),
                               locale: locale)
            : nil,
         links > 0
            ? CountCopy.phrase(links,
                               one: String(localized: "statusBar.links.one", defaultValue: "%@ link"),
                               many: String(localized: "statusBar.links.many", defaultValue: "%@ links"),
                               locale: locale)
            : nil]
    }
}
