// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - What the app gives the About-the-Series and Chronology suites, for the package

// In Xcode the suites run inside the app: the bundled aggregates are in `Bundle.main`, the app's two
// stores read them from there, and `ChronologyViewModel`'s names forward to the kit's
// `ChronologyGrouping` and `VolumeLabels`. The package has no bundle and no app, so it declares the
// same names here, over the repository's copies of the bundled files and the kit's own rules, and the
// suites call them as they do in Xcode.
//
// Version history:
//   1.0 — 2026-11-12 (FRUS Explorer Light, S24b): initial implementation, when About the Series' data
//          and Chronology's rules moved into the kit

/// A file bundled with the app, by name and extension: in the test host's bundle in Xcode, and in the
/// repository's `FRUSExplorer/Resources` in the package; `nil` when it is not there.
func appBundledURL(forResource name: String, withExtension ext: String) -> URL? {
    #if SWIFT_PACKAGE
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer/Resources/\(name).\(ext)")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
    #else
    return Bundle.main.url(forResource: name, withExtension: ext)
    #endif
}

#if SWIFT_PACKAGE
/// The app's `SourceProvenanceStore`, as the package's suites need it: the repository's
/// `source-provenance-index.json` through the kit's loader, `nil` where the store's would be.
@MainActor
final class SourceProvenanceStore {
    let index: SourceProvenanceIndex?
    init() {
        index = appBundledURL(forResource: "source-provenance-index", withExtension: "json")
            .flatMap { try? SourceProvenanceIndex(contentsOf: $0) }
    }
    init(index: SourceProvenanceIndex?) { self.index = index }
}

/// The app's `AdministrationProfilesStore`, as the package's suites need it: the repository's
/// `administration-profiles-index.json` through the kit's loader, `nil` where the store's would be.
@MainActor
final class AdministrationProfilesStore {
    let index: AdministrationProfilesIndex?
    init() {
        index = appBundledURL(forResource: "administration-profiles-index", withExtension: "json")
            .flatMap { try? AdministrationProfilesIndex(contentsOf: $0) }
    }
    init(index: AdministrationProfilesIndex?) { self.index = index }
}

/// `ChronologyViewModel`'s static names that the suites call, over the kit's rules, where the app's
/// forward.
enum ChronologyViewModel {
    static let loadLimit = ChronologyGrouping.loadLimit
    static let dayGroupingMaxDays = ChronologyGrouping.dayGroupingMaxDays
    static let monthGroupingMaxDays = ChronologyGrouping.monthGroupingMaxDays
    static let maxSpanDaysForPlacement = ChronologyGrouping.maxSpanDaysForPlacement
    static let volumeTopicMaxLength = VolumeLabels.volumeTopicMaxLength

    static func partition(_ rows: [ChronologyRow]) -> (placed: [ChronologyRow], spanning: [ChronologyRow]) {
        ChronologyGrouping.partition(rows)
    }
    static func splitOverflow(_ placed: [ChronologyRow], startISO: String,
                              endISO: String) -> (inRange: [ChronologyRow], overflow: [ChronologyRow]) {
        ChronologyGrouping.splitOverflow(placed, startISO: startISO, endISO: endISO)
    }
    static func overflowDirection(_ row: ChronologyRow, startISO: String,
                                  endISO: String) -> (leading: Bool, trailing: Bool) {
        ChronologyGrouping.overflowDirection(row, startISO: startISO, endISO: endISO)
    }
    static func overflowCounts(_ rows: [ChronologyRow], startISO: String, endISO: String,
                               locale: Locale = .autoupdatingCurrent) -> ChronologyOverflowCounts {
        ChronologyGrouping.overflowCounts(rows, startISO: startISO, endISO: endISO, locale: locale)
    }
    static func spanningChipTitle(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        ChronologyGrouping.spanningChipTitle(count, locale: locale)
    }
    static func spanningChipAccessibilityLabel(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        ChronologyGrouping.spanningChipAccessibilityLabel(count, locale: locale)
    }
    static var spanningSectionHeader: String { ChronologyGrouping.spanningSectionHeader }
    static func magnifierBreakdown(for group: ChronologyDateGroup) -> [ChronologyMagnifierBar] {
        ChronologyGrouping.magnifierBreakdown(for: group)
    }
    static func magnifierBarsByBucket(counts: [(bucketKey: String, volumeId: String, count: Int)],
                                      parentPrefix: Int, volumeBreakdown: Bool) -> [String: [ChronologyMagnifierBar]] {
        ChronologyGrouping.magnifierBarsByBucket(counts: counts, parentPrefix: parentPrefix,
                                                 volumeBreakdown: volumeBreakdown)
    }
    static func startOfBucket(_ date: Date, bucket: DateBucket, calendar: Calendar) -> Date {
        ChronologyGrouping.startOfBucket(date, bucket: bucket, calendar: calendar)
    }
    static func endOfBucket(_ date: Date, bucket: DateBucket, calendar: Calendar) -> Date {
        ChronologyGrouping.endOfBucket(date, bucket: bucket, calendar: calendar)
    }
    static func makeChart(from groups: [ChronologyDateGroup],
                          maxSeries: Int) -> (buckets: [ChronologyChartBucket], series: [ChronologyChartSeries]) {
        ChronologyGrouping.makeChart(from: groups, maxSeries: maxSeries)
    }
    static func makeChart(fromCounts counts: [(bucketKey: String, volumeId: String, count: Int)], viewBucket: DateBucket,
                          maxSeries: Int) -> (buckets: [ChronologyChartBucket], series: [ChronologyChartSeries]) {
        ChronologyGrouping.makeChart(fromCounts: counts, viewBucket: viewBucket, maxSeries: maxSeries)
    }
    static func distilledVolumeLabel(volumeId: String, subseries: String, title: String) -> String {
        VolumeLabels.distilledVolumeLabel(volumeId: volumeId, subseries: subseries, title: title)
    }
    static func distilledVolumeLabelParts(volumeId: String, subseries: String, title: String) -> VolumeLabelParts {
        VolumeLabels.distilledVolumeLabelParts(volumeId: volumeId, subseries: subseries, title: title)
    }
}
#endif
