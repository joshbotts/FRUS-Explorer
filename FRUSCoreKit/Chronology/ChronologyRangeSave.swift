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

// MARK: - ChronologyRangeEntry

/// One document of a range of dates as Chronology's save reads it (L56): its key and its two dates, with none of the
/// list's display fields. ``IndexingPipeline/documentDatesInDateRange(_:)`` reads them in date order: every document
/// the list's query takes, none of them cut by the list's limit.
///
/// Version history:
///   1.0 — 2026-11-27 (L56): initial implementation
public struct ChronologyRangeEntry: Equatable, Sendable {
    /// The document's volume.
    public let volumeId: String
    /// The document's id in its volume.
    public let documentId: String
    /// The first day of its dates, `yyyy-MM-dd`.
    public let dateISO: String
    /// The last day of its dates, or `nil` where the index stored a single day.
    public let dateISOMax: String?

    /// An entry of exactly these values.
    public init(volumeId: String, documentId: String, dateISO: String, dateISOMax: String?) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.dateISO = dateISO
        self.dateISOMax = dateISOMax
    }

    /// The `"volumeId/documentId"` key a working corpus keeps.
    public var key: String { "\(volumeId)/\(documentId)" }
}

// MARK: - ChronologyRangeKind

/// The three kinds of document a range of dates holds, as Chronology's screen divides them: those dated inside it,
/// which the date sections list; those whose dates extend beyond it, under one chip; and those that span more than a
/// year, under another. ``ChronologyGrouping/kind(dateISO:dateISOMax:startISO:endISO:)`` says which a document is.
///
/// Version history:
///   1.0 — 2026-11-27 (L56): initial implementation
public enum ChronologyRangeKind: Equatable, Sendable, CaseIterable {
    /// Placed on a day, and dated wholly inside the range.
    case datedInside
    /// Placed on a day, with dates that begin before the range or end after it.
    case extendsBeyond
    /// Dated across more than ``ChronologyGrouping/maxSpanDaysForPlacement`` days: mostly editorial notes.
    case spansMoreThanAYear
}

// MARK: - ChronologyRangeSave

/// What Chronology saves as a working corpus from the range it loaded (decisions 184 and 185, L56): the rule, over the
/// range's documents, that says which of them the save holds, which range it names, how many of each kind it holds,
/// and the sentences said before it and the name it is saved under.
///
/// ## What it holds
/// Every document whose dates overlap the range, of all three kinds (``ChronologyRangeKind``). That is the set Search's
/// date filter means by a range, so a count taken inside the corpus agrees, at capture, with a search under the same
/// dates. The legend's filter, which narrows the list to a volume, does not narrow it (decision 185).
///
/// ## Over the record's budget
/// A working corpus keeps at most ``SemanticMapPicking/corpusCaptureLimit`` keys. Over it, the save names the range cut
/// at the last whole day that fits and holds every document of that shorter range, so nothing is recorded as cut short
/// (decision 185); a second save from the next day on takes the rest, and with it the documents whose dates reach across
/// that day, which both then hold. A document is in a range when its dates overlap it, and every document read overlaps
/// the whole range, so the documents of the range cut at a day are those whose first day is on or before it: the rule
/// reads the documents' first days, in any order.
///
/// Measured on 2026-11-27 on a full index at version 76 (553 volumes), through this rule: 12,030 documents overlap 1945,
/// the fullest year, whose save ends on 14 August with 7,492 of them; one from 15 August holds 4,942, 404 of them in
/// both. 1944, 1949, 1946, 1951, 1943, 1948 and 1954 pass the budget too. No year's first day is overlapped by more
/// than 1,507 documents (1 January 1953), so a range whose first day with documents passes the budget
/// (``Plan/firstDayOverLimit(day:count:)``) is the rule's case and not the corpus's.
///
/// ## The record
/// ``workingCorpus(stamp:locale:)`` is the capture the app's one helper writes, with its question before the save and
/// its toast after it, as L42 made the cross-reference graph's: named by rule, for the range's two days with the
/// capture's stamp (decision 185); described by Chronology and the range, which is enough to make the set again by
/// hand; with no query, since no words produced it; and with nothing recorded as cut short.
///
/// Version history:
///   1.0 — 2026-11-27 (L56): initial implementation
public struct ChronologyRangeSave: Equatable, Sendable {

    /// What a save of a range does: saves the range or a shorter one, or saves nothing, and why.
    ///
    /// Version history:
    ///   1.0 — 2026-11-27 (L56): initial implementation
    public enum Plan: Equatable, Sendable {
        /// Saves the range, or the range cut at the last whole day that fits.
        case saves(ChronologyRangeSave)
        /// The range holds no document.
        case empty
        /// The range's first day with documents, `day`, is overlapped by more of them than a working corpus keeps,
        /// `count`, so no whole day of the range fits: the range's first day where documents begin before it, and
        /// otherwise the day the first of them begins.
        case firstDayOverLimit(day: String, count: Int)
    }

    /// The first day of the range the save names, `yyyy-MM-dd`: the loaded range's first.
    public let startISO: String
    /// The last day of the range the save names: the loaded range's last, or the last whole day that fits.
    public let endISO: String
    /// The last day of the range the screen loaded.
    public let loadedEndISO: String
    /// How many documents the loaded range holds, the save's among them.
    public let loadedCount: Int
    /// The documents the save holds, as `"volumeId/documentId"` keys, in the order they were read.
    public let documentKeys: [String]
    /// How many it holds dated inside the range it names.
    public let datedInside: Int
    /// How many it holds whose dates extend beyond the range it names.
    public let extendingBeyond: Int
    /// How many it holds that span more than a year.
    public let spanning: Int
    /// The most a working corpus keeps, to which the save was cut.
    public let limit: Int

    /// Whether the save names a shorter range than the screen loaded.
    public var isCut: Bool { endISO != loadedEndISO }

    /// How many documents the save holds.
    public var count: Int { documentKeys.count }

    // MARK: The rule

    /// What a save of the range `startISO`…`endISO`, both days included, does.
    ///
    /// - Parameters:
    ///   - entries: Every document whose dates overlap the range, as ``IndexingPipeline/documentDatesInDateRange(_:)``
    ///     reads them; the save keeps them in this order.
    ///   - startISO: The range's first day, `yyyy-MM-dd`.
    ///   - endISO: Its last day.
    ///   - limit: The most a working corpus keeps.
    /// - Returns: What the save does.
    public static func plan(entries: [ChronologyRangeEntry], startISO: String, endISO: String,
                            limit: Int = SemanticMapPicking.corpusCaptureLimit) -> Plan {
        guard !entries.isEmpty else { return .empty }
        var savedEnd = endISO
        var kept = entries
        if entries.count > limit {
            // The documents of the range up to a day are those that begin on or before it. So the first day past the
            // budget is the one on which the (limit + 1)th document, by first day, begins, and the save ends the day
            // before it.
            let firstDays = entries.map { day(of: $0.dateISO) }.sorted()
            // That day must be in the range and hold a document: when the documents that begin on the first day
            // with any, or before the range, are already more than the budget, no whole day fits.
            guard let lastDayThatFits = dayBefore(firstDays[limit]),
                  lastDayThatFits >= startISO, firstDays[0] <= lastDayThatFits else {
                let crowded = max(startISO, firstDays[0])
                return .firstDayOverLimit(day: crowded, count: firstDays.prefix { $0 <= crowded }.count)
            }
            savedEnd = lastDayThatFits
            kept = entries.filter { day(of: $0.dateISO) <= lastDayThatFits }
        }
        var counts: [ChronologyRangeKind: Int] = [:]
        for entry in kept {
            counts[ChronologyGrouping.kind(dateISO: entry.dateISO, dateISOMax: entry.dateISOMax,
                                           startISO: startISO, endISO: savedEnd), default: 0] += 1
        }
        return .saves(ChronologyRangeSave(
            startISO: startISO, endISO: savedEnd, loadedEndISO: endISO, loadedCount: entries.count,
            documentKeys: kept.map(\.key), datedInside: counts[.datedInside] ?? 0,
            extendingBeyond: counts[.extendsBeyond] ?? 0, spanning: counts[.spansMoreThanAYear] ?? 0,
            limit: limit))
    }

    // MARK: The record

    /// What the set is, as its name begins: "Chronology, Oct 1 – 31, 1962".
    ///
    /// - Parameter locale: The locale the two days are written in.
    /// - Returns: The subject.
    public func subject(locale: Locale = .autoupdatingCurrent) -> String {
        String(format: String(localized: "chronology.save.subject %@", defaultValue: "Chronology, %@"),
               Self.rangePhrase(startISO: startISO, endISO: endISO, locale: locale))
    }

    /// Where the set came from, as the corpus records it and the question says first: Chronology, the range's two
    /// days, and the rule that took its documents, which is enough to make the set again by hand.
    ///
    /// - Parameter locale: The locale the two days are written in.
    /// - Returns: The description.
    public func sourceDescription(locale: Locale = .autoupdatingCurrent) -> String {
        String(format: String(localized: "chronology.save.source %@",
                              defaultValue: "Chronology, %@: every document whose dates overlap the range"),
               Self.rangePhrase(startISO: startISO, endISO: endISO, locale: locale))
    }

    /// The working corpus the save writes: its documents, named for the range with the capture's stamp
    /// (``WorkingCorpusCapture/name(subject:stamp:)``) and described by ``sourceDescription(locale:)``. It holds no
    /// more than ``limit`` documents, so the record says it is every document of the range it names.
    ///
    /// - Parameters:
    ///   - stamp: When the save is made (``WorkingCorpusCapture/stamp(for:locale:timeZone:)``).
    ///   - locale: The locale the two days are written in.
    /// - Returns: The capture.
    public func workingCorpus(stamp: String, locale: Locale = .autoupdatingCurrent) -> WorkingCorpusCapture {
        WorkingCorpusCapture(name: WorkingCorpusCapture.name(subject: subject(locale: locale), stamp: stamp),
                             keys: documentKeys, sourceDescription: sourceDescription(locale: locale))
    }

    // MARK: What the save says

    /// The sentences the question says after the description and the coverage, in order: where the budget cut the
    /// range, how many documents of each kind the save holds, and, when the legend's filter narrows the list, that it
    /// does not narrow the save.
    ///
    /// - Parameters:
    ///   - legendFiltered: Whether the legend's filter narrows the list.
    ///   - locale: The locale that writes the days and groups the counts.
    /// - Returns: The sentences.
    public func notes(legendFiltered: Bool, locale: Locale = .autoupdatingCurrent) -> [String] {
        var notes: [String] = []
        if let cut = cutSentence(locale: locale) { notes.append(cut) }
        notes.append(kindsSentence(locale: locale))
        if legendFiltered { notes.append(Self.legendFilterSentence) }
        return notes
    }

    /// How many documents of each kind the save holds, the kinds it holds none of left out: "500 are dated inside the
    /// range, 25 extend beyond the range, and 670 span more than a year."
    ///
    /// - Parameter locale: The locale that groups the counts and joins the parts.
    /// - Returns: The sentence.
    public func kindsSentence(locale: Locale = .autoupdatingCurrent) -> String {
        var parts: [String] = []
        if datedInside > 0 {
            parts.append(CountCopy.phrase(
                datedInside,
                one: String(localized: "chronology.save.kind.inside.one %@", defaultValue: "%@ is dated inside the range"),
                many: String(localized: "chronology.save.kind.inside.many %@", defaultValue: "%@ are dated inside the range"),
                locale: locale))
        }
        if extendingBeyond > 0 {
            parts.append(CountCopy.phrase(
                extendingBeyond,
                one: String(localized: "chronology.save.kind.beyond.one %@", defaultValue: "%@ extends beyond the range"),
                many: String(localized: "chronology.save.kind.beyond.many %@", defaultValue: "%@ extend beyond the range"),
                locale: locale))
        }
        if spanning > 0 {
            parts.append(CountCopy.phrase(
                spanning,
                one: String(localized: "chronology.save.kind.spanning.one %@", defaultValue: "%@ spans more than a year"),
                many: String(localized: "chronology.save.kind.spanning.many %@", defaultValue: "%@ span more than a year"),
                locale: locale))
        }
        return parts.formatted(.list(type: .and).locale(locale)) + "."
    }

    /// Where the budget cut the range, said before the save, or `nil` when it saves the whole range: "Jan 1 – Dec 31,
    /// 1945 holds 12,030 documents, more than the 7,500 a working corpus keeps, so the save ends on Aug 14, 1945, the
    /// last whole day that fits. To save the rest, save again from Aug 15, 1945."
    ///
    /// - Parameter locale: The locale that writes the days and groups the counts.
    /// - Returns: The sentence, or `nil`.
    public func cutSentence(locale: Locale = .autoupdatingCurrent) -> String? {
        guard isCut, let nextDay = Self.dayAfter(endISO) else { return nil }
        return String(format: String(localized: "chronology.save.cut %@ %@ %@ %@ %@",
                                     defaultValue: "%1$@ holds %2$@ documents, more than the %3$@ a working corpus keeps, so the save ends on %4$@, the last whole day that fits. To save the rest, save again from %5$@."),
                      Self.rangePhrase(startISO: startISO, endISO: loadedEndISO, locale: locale),
                      loadedCount.formatted(.number.locale(locale)),
                      limit.formatted(.number.locale(locale)),
                      Self.dayPhrase(endISO, locale: locale),
                      Self.dayPhrase(nextDay, locale: locale))
    }

    /// Said before the save while the legend's filter narrows the list to a volume, or to the volumes the chart folds
    /// into *Other*: the filter does not narrow the save (decision 185).
    public static var legendFilterSentence: String {
        String(localized: "chronology.save.legendFilter",
               defaultValue: "The legend’s filter narrows the list and not the save, which holds every volume’s documents.")
    }

    /// What the screen says when the range holds no document, so there is nothing to ask about: which only an index
    /// changed since the screen loaded can leave, since the save is offered only over a range that holds one.
    public static var nothingToSave: String {
        String(localized: "chronology.save.empty",
               defaultValue: "The range holds no document, so there is nothing to save.")
    }

    /// What the screen says when the range's first day with documents passes the budget
    /// (``Plan/firstDayOverLimit(day:count:)``), in place of the question, since no save is offered.
    ///
    /// - Parameters:
    ///   - day: The range's first day with documents, `yyyy-MM-dd`.
    ///   - count: How many documents overlap it.
    ///   - limit: The most a working corpus keeps.
    ///   - locale: The locale that writes the day and groups the counts.
    /// - Returns: The sentence.
    public static func firstDayOverLimitSentence(day: String, count: Int,
                                                 limit: Int = SemanticMapPicking.corpusCaptureLimit,
                                                 locale: Locale = .autoupdatingCurrent) -> String {
        String(format: String(localized: "chronology.save.firstDayOver %@ %@ %@",
                              defaultValue: "The range cannot be saved: its first day with documents, %1$@, holds %2$@ of them, more than the %3$@ a working corpus keeps."),
               dayPhrase(day, locale: locale), count.formatted(.number.locale(locale)),
               limit.formatted(.number.locale(locale)))
    }

    // MARK: Days

    /// A range's two days in words, as a corpus's name and description carry them: "Oct 1 – 31, 1962" in the United
    /// States. Read and written in UTC, so each is the day written in any zone, as the graph's brushed range is
    /// written with its template.
    ///
    /// - Parameters:
    ///   - startISO: The first day, `yyyy-MM-dd`.
    ///   - endISO: The last day.
    ///   - locale: The locale they are written in.
    /// - Returns: The phrase, or the two days as written when one does not read as a day.
    public static func rangePhrase(startISO: String, endISO: String,
                                   locale: Locale = .autoupdatingCurrent) -> String {
        guard let start = date(ofDay: startISO), let end = date(ofDay: endISO) else {
            return "\(startISO) – \(endISO)"
        }
        let formatter = DateIntervalFormatter()
        formatter.calendar = utcCalendar
        formatter.timeZone = utcCalendar.timeZone
        formatter.locale = locale
        formatter.dateTemplate = "MMM d y"
        return formatter.string(from: start, to: end)
    }

    /// One day in words, "Aug 14, 1945" in the United States, written in UTC as ``rangePhrase(startISO:endISO:locale:)``
    /// writes two.
    ///
    /// - Parameters:
    ///   - iso: The day, `yyyy-MM-dd`.
    ///   - locale: The locale it is written in.
    /// - Returns: The phrase, or the day as written when it does not read as one.
    public static func dayPhrase(_ iso: String, locale: Locale = .autoupdatingCurrent) -> String {
        guard let date = date(ofDay: iso) else { return iso }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale,
                                               calendar: utcCalendar, timeZone: utcCalendar.timeZone))
    }

    /// The day before `iso`, `yyyy-MM-dd`, or `nil` when `iso` does not read as a day.
    static func dayBefore(_ iso: String) -> String? { shifted(iso, byDays: -1) }

    /// The day after `iso`, `yyyy-MM-dd`, or `nil` when `iso` does not read as a day.
    static func dayAfter(_ iso: String) -> String? { shifted(iso, byDays: 1) }

    /// The first ten characters of an index date, its day, as Chronology's rules compare them.
    private static func day(of iso: String) -> String { String(iso.prefix(10)) }

    /// A Gregorian calendar in UTC, in which a `yyyy-MM-dd` day is the day written in any zone.
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }

    /// The midnight in UTC that begins `iso`, or `nil` when it does not read as a day.
    private static func date(ofDay iso: String) -> Date? {
        let parts = day(of: iso).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return utcCalendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// `iso` moved by `days` days.
    private static func shifted(_ iso: String, byDays days: Int) -> String? {
        guard let date = date(ofDay: iso),
              let moved = utcCalendar.date(byAdding: .day, value: days, to: date) else { return nil }
        let parts = utcCalendar.dateComponents([.year, .month, .day], from: moved)
        guard let year = parts.year, let month = parts.month, let dayOfMonth = parts.day else { return nil }
        return "\(padded(year, to: 4))-\(padded(month, to: 2))-\(padded(dayOfMonth, to: 2))"
    }

    /// `n` written with leading zeros to `width` digits.
    private static func padded(_ n: Int, to width: Int) -> String {
        let digits = String(n)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
