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

import Testing
import Foundation
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - SkippedMidnightDay

/// A day whose midnight a change of clocks skips, in its zone: the clocks there went from 23:59 to 01:00 or later, so
/// the day has no 00:00, and a strict `DateFormatter` in the zone reads it as no date (#2033).
///
/// The days are #2033's, measured by L57 on iOS 27.0's Foundation: the first three of each zone in its table of the
/// days from 1861 to 2000, and its four recent days. The app's Search tests read them too
/// (`SearchDateFilterZoneTests`).
///
/// Version history:
///   1.0 — #2033 (L62): initial implementation
struct SkippedMidnightDay: Sendable, CustomTestStringConvertible {
    /// The zone's identifier.
    let zoneID: String
    /// The day, as `yyyy-MM-dd`.
    let day: String

    /// The day and its zone, as a test's argument is named in a run's log.
    var testDescription: String { "\(day) in \(zoneID)" }

    /// The zone, which every identifier here names.
    func zone() throws -> TimeZone {
        try #require(TimeZone(identifier: zoneID), "no zone \(zoneID)")
    }

    /// The day's year, month and day.
    func components() throws -> (year: Int, month: Int, day: Int) {
        let fields = day.split(separator: "-").compactMap { Int($0) }
        try #require(fields.count == 3, "\(day) is not yyyy-MM-dd")
        return (fields[0], fields[1], fields[2])
    }

    /// The day's noon in its zone, a moment the day certainly has.
    func noon() throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try zone()
        let (year, month, dayOfMonth) = try components()
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: 12)))
    }

    /// The day `date` falls on in this day's zone, read by a formatter, as a date picker there shows it, and not by any
    /// function under test.
    func shownDay(_ date: Date) throws -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = try zone()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Every day of the issue's: 21 from its table and four recent ones.
    static let all: [SkippedMidnightDay] = [
        SkippedMidnightDay(zoneID: "America/Sao_Paulo", day: "1914-01-01"),
        SkippedMidnightDay(zoneID: "America/Sao_Paulo", day: "1932-10-03"),
        SkippedMidnightDay(zoneID: "America/Sao_Paulo", day: "1949-12-01"),
        SkippedMidnightDay(zoneID: "America/Havana", day: "1928-06-10"),
        SkippedMidnightDay(zoneID: "America/Havana", day: "1940-06-02"),
        SkippedMidnightDay(zoneID: "America/Havana", day: "1941-06-01"),
        SkippedMidnightDay(zoneID: "Asia/Beirut", day: "1920-03-28"),
        SkippedMidnightDay(zoneID: "Asia/Beirut", day: "1921-04-03"),
        SkippedMidnightDay(zoneID: "Asia/Beirut", day: "1922-03-26"),
        SkippedMidnightDay(zoneID: "America/Santiago", day: "1916-07-01"),
        SkippedMidnightDay(zoneID: "America/Santiago", day: "1918-09-10"),
        SkippedMidnightDay(zoneID: "America/Santiago", day: "1927-09-01"),
        SkippedMidnightDay(zoneID: "Asia/Tehran", day: "1935-06-13"),
        SkippedMidnightDay(zoneID: "Asia/Tehran", day: "1978-03-25"),
        SkippedMidnightDay(zoneID: "Asia/Tehran", day: "1979-05-26"),
        SkippedMidnightDay(zoneID: "Africa/Cairo", day: "1940-07-15"),
        SkippedMidnightDay(zoneID: "Africa/Cairo", day: "1941-04-15"),
        SkippedMidnightDay(zoneID: "Africa/Cairo", day: "1942-04-01"),
        SkippedMidnightDay(zoneID: "Asia/Tokyo", day: "1948-05-02"),
        SkippedMidnightDay(zoneID: "Asia/Tokyo", day: "1949-04-03"),
        SkippedMidnightDay(zoneID: "Asia/Tokyo", day: "1950-05-07"),
        SkippedMidnightDay(zoneID: "America/Sao_Paulo", day: "2018-11-04"),
        SkippedMidnightDay(zoneID: "America/Havana", day: "2024-03-10"),
        SkippedMidnightDay(zoneID: "Asia/Beirut", day: "2024-03-31"),
        SkippedMidnightDay(zoneID: "America/Santiago", day: "2024-09-08"),
    ]
}

// MARK: - WordCloudDateRangeSkippedMidnightTests

/// The word cloud's date range on a day whose midnight a change of clocks skips (#2033).
///
/// ## The defect
/// `WordCloudScope.day(fromISO:)` read a range's two days with a strict `DateFormatter` in the device's zone, which
/// reads such a day as no date. The range's two pickers then fell back to the year 1 (`.distantPast`) and to now
/// (`WordCloudView.swift`), its title printed the day's string, and *View in Chronology* handed Chronology no day.
///
/// ## Why every test names its zone
/// A unit test's process runs in the Mac's zone, New York's, which skips no midnight from 1861 to 2000, and the CI's
/// runner is in UTC, which skips none. So the conversions take their zone, and the tests pass the day's own.
///
/// Version history:
///   1.0 — #2033 (L62): initial implementation
@Suite("The word cloud's date range, on a day whose midnight a change of clocks skips (#2033)")
struct WordCloudDateRangeSkippedMidnightTests {

    @Test("A range's day is read as the day's first moment there, and written back as itself",
          arguments: SkippedMidnightDay.all)
    func aDayIsReadAsItsFirstMoment(_ skipped: SkippedMidnightDay) throws {
        let zone = try skipped.zone()
        let date = try #require(WordCloudScope.day(fromISO: skipped.day, in: zone),
                                "\(skipped.testDescription) read as no date: the pickers fall back to year 1 and now")
        #expect(try skipped.shownDay(date) == skipped.day, "the picker shows another day")
        #expect(try skipped.shownDay(date.addingTimeInterval(-1)) != skipped.day, "not the day's first moment")
        #expect(WordCloudScope.isoDay(from: date, in: zone) == skipped.day, "written back as another day")
    }

    @Test("A range's title names its days in words, as on any other day", arguments: SkippedMidnightDay.all)
    func theTitleNamesTheDays(_ skipped: SkippedMidnightDay) throws {
        let zone = try skipped.zone()
        let title = WordCloudScope.dateRangeTitle(startISO: skipped.day, endISO: skipped.day, in: zone)
        // The title's own template and locale, over a moment the day certainly has.
        let display = DateFormatter()
        display.locale = .autoupdatingCurrent
        display.timeZone = zone
        display.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        let words = try display.string(from: skipped.noon())
        #expect(!title.contains(skipped.day), "the title prints the day's string: \(title)")
        #expect(title.contains(words), "the title does not name \(words): \(title)")
    }
}
