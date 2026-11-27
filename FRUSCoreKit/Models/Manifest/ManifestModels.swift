// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Volume Manifest Entry

/// Rich metadata for a single FRUS volume, decoded from the bundled `manifest.json`.
///
/// The manifest is generated at release time by the `ManifestGenerator` SPM tool and
/// committed to the repository. At app launch, `ManifestStore` decodes this from the
/// app bundle and merges it with the live GitHub API response.
///
/// The `tags` array contains volume-level subject tag slugs curated by OH staff and
/// embedded in each volume's published TEI (resolved via `VolumeLevelTag`). An empty
/// array is valid — some volumes predate the tagging system.
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — #1504: the per-volume document count removed. No generator ever filled it — the TEI
///          header cannot say how many documents a volume holds — so it was 0 in all 553 rows, and
///          its one reader, Citation Lookup's nearest-document strategy, never answered (owner
///          decision D6). A volume's document count is
///          `AdministrationProfilesStore.documentCount(forVolumeId:)`.
public struct VolumeManifestEntry: Codable, Sendable, Identifiable, Equatable {
    /// Unique identifier derived from the volume filename without extension.
    /// e.g. `"frus1969-76v01"`. Acts as the stable primary key across all data layers.
    public let volumeId: String

    /// Bare filename, e.g. `"frus1969-76v01.xml"`.
    public let filename: String

    /// Chronological subseries identifier extracted from the filename.
    /// e.g. `"1969-76"`, `"1977-80"`, `"1861"`. Used to group volumes in the Browser view.
    public let subseries: String

    /// Full volume title from the TEI `<titleStmt>`, with whitespace normalized.
    /// The raw TEI XML preserves indentation inside the title element, producing embedded
    /// newlines and runs of spaces. These are collapsed to single spaces on decode.
    public let title: String

    /// Earliest and latest document dates within the volume.
    public let dateRange: DateRange

    /// Publication date as a free-form string from the TEI `<publicationStmt>`.
    /// Typically a year (`"2003"`) or ISO date. `nil` if absent from the TEI header.
    public let publicationDate: String?

    /// Publication status.
    public let status: VolumeStatus

    /// Primary editors, excluding the general editor.
    public let editors: [String]

    /// The general editor of the subseries, if listed.
    public let generalEditor: String?

    /// File size in bytes as reported by the GitHub API. Used for download size estimates.
    public let sizeBytes: Int

    /// Volume-level subject tag slugs from the TEI `<teiHeader>`.
    /// Resolve against `VolumeLevelTagStore` for display names and hierarchy.
    public let tags: [String]

    /// Where this entry came from — the published catalogue, or the user's own file (#777).
    ///
    /// Defaulted and **not decoded**, so `manifest.json` is unchanged and every one of its 553
    /// entries is `.publishedCatalogue` without a byte moving. Only `LocalVolumeCatalog` mints
    /// the other case.
    public var provenance: VolumeOrigin = .publishedCatalogue

    public var id: String { volumeId }

    /// Constructs the GitHub raw download URL for this volume.
    ///
    /// Derived from `filename` at call time rather than stored in the manifest,
    /// since the URL scheme is stable and this avoids regenerating the manifest
    /// whenever GitHub changes the raw host (which it hasn't in a decade).
    ///
    /// Version history:
    ///   1.0 — New UI scaffolding: added so new macOS UI can enqueue downloads
    ///          without constructing the URL inline at every call site.
    ///   1.1 — Session 2026-08-09 (#777): **optional.** A side-loaded volume has no catalogue
    ///          URL, and this property is computed FROM THE FILENAME — so returning one anyway
    ///          would hand every repair path a plausible GitHub address that 404s, or, worse,
    ///          silently resolves to a *different* volume if that filename is later published.
    ///          The optionality is the mechanism, not a nicety: it makes every consumer confront
    ///          the missing URL at compile time.
    public var downloadUrl: String? {
        guard provenance == .publishedCatalogue else { return nil }
        return "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(filename)"
    }
}

// MARK: - VolumeOrigin

// (Named `VolumeOrigin`, not `VolumeProvenance`: SA-3's `SourceProvenanceData` already owns
// that name for a per-volume archival-provenance row, an unrelated idea.)

/// Whether a volume entry describes something the app can fetch, or something the user supplied.
///
/// The distinction is not bookkeeping. It decides three things that would otherwise be wrong for a
/// side-loaded volume: whether a download URL exists at all (`downloadUrl`), whether Free Up Space
/// may offer to delete it (`StorageRemovalPlan`), and — the one that matters most — whether a
/// citation may claim the document is published (`FRUSVolumeMetadata`). A pre-release cited as
/// published, with a canonical `history.state.gov` URL that resolves to nothing, is worse than no
/// citation at all.
///
/// Version history:
///   1.0 — Session 2026-08-09: #777
public enum VolumeOrigin: String, Codable, Sendable, Equatable {
    /// From `manifest.json` — the published FRUS catalogue.
    case publishedCatalogue
    /// From a file the user side-loaded. Not necessarily unpublished, but the app cannot tell.
    case sideloaded
}

// Custom Decodable conformance in an extension so the synthesized memberwise
// initializer is preserved for test construction.
extension VolumeManifestEntry {
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        volumeId        = try c.decode(String.self, forKey: .volumeId)
        filename        = try c.decode(String.self, forKey: .filename)
        subseries       = try c.decode(String.self, forKey: .subseries)
        let rawTitle    = try c.decode(String.self, forKey: .title)
        title           = rawTitle
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        dateRange       = try c.decode(DateRange.self, forKey: .dateRange)
        publicationDate = try c.decodeIfPresent(String.self, forKey: .publicationDate)
        status          = try c.decode(VolumeStatus.self, forKey: .status)
        editors         = try c.decode([String].self, forKey: .editors)
        generalEditor   = try c.decodeIfPresent(String.self, forKey: .generalEditor)
        sizeBytes       = try c.decode(Int.self, forKey: .sizeBytes)
        let rawTags     = try c.decode([String].self, forKey: .tags)
        tags            = rawTags.reduce(into: [String]()) { seen, slug in
            if !seen.contains(slug) { seen.append(slug) }
        }
    }
}

/// Publication status of a FRUS volume.
public enum VolumeStatus: String, Codable, Sendable {
    case published
    case partiallyPublished
    case planned
}

/// The date range of documents within a FRUS volume.
///
/// Both values are ISO 8601 strings. Either may be `nil` for volumes where the TEI
/// header does not contain date-range information.
public struct DateRange: Codable, Sendable, Equatable {
    public let earliest: String?
    public let latest: String?

    /// Memberwise, spelled out because `public` suppresses the synthesized one; public because a
    /// search's date filter (`SearchParameters.dateRange`) is one, and FRUS Explorer Light builds
    /// its searches from outside the kit (FRUSCoreKit, part 2).
    public init(earliest: String?, latest: String?) {
        self.earliest = earliest
        self.latest = latest
    }
}

// MARK: - A Day's Two Conversions (#2013, #2033)

/// A `yyyy-MM-dd` day and the date a date picker in a zone holds for it.
///
/// A day string names a calendar day, with no zone; the date a picker holds is a moment in the picker's zone, which is
/// the device's. Search's date filter on iPhone, iPad and the Mac converts between the two through this pair
/// (`SearchViewModel.filterDay(of:in:)`, `filterDate(ofDay:in:)`, which L57 wrote for #2013 and L62 moved here), and so
/// does the word cloud's date range (`WordCloudScope.isoDay(from:in:)`, `day(fromISO:in:)`).
extension DateRange {

    /// The `yyyy-MM-dd` day `date` falls on in `timeZone`: the day a date picker in that zone shows it on.
    ///
    /// - Parameters:
    ///   - date: A moment.
    ///   - timeZone: The zone to read its day in.
    /// - Returns: The day, as `yyyy-MM-dd`.
    public static func day(of date: Date, in timeZone: TimeZone) -> String {
        let day = dayCalendar(in: timeZone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }

    /// The first moment of the day `day` names in `timeZone`, or `nil` when `day` is not a `yyyy-MM-dd` day there.
    ///
    /// The date a date picker in that zone shows `day` for. It is the day's noon taken back to the day's start, not a
    /// formatter's reading: where a change of clocks skips a day's midnight, the day starts at the first moment it has,
    /// where a strict `DateFormatter` reads no date at all (#2033). From 1861 to 2000 there are 27 such days in São
    /// Paulo, 42 in Havana and 4 in Tokyo, by L57's measurement on iOS 27.0's Foundation and L62's on macOS 27.2's. Most
    /// begin at 01:00, and a few minutes past midnight where a zone left a local mean time (São Paulo's 1 January 1914
    /// at 00:06:28). A noon that a change of clocks skips is read forward within its day (Havana's 19 July 1925), so
    /// that day still starts at its midnight; a day the clocks skip whole is no day (Samoa's 30 December 2011).
    ///
    /// - Parameters:
    ///   - day: A day, as `yyyy-MM-dd`.
    ///   - timeZone: The zone the day is in.
    /// - Returns: The day's first moment, or `nil` for a string that names no day there (`1962-02-30`, `1962-10-1`).
    public static func firstMoment(ofDay day: String, in timeZone: TimeZone) -> Date? {
        let fields = day.split(separator: "-", omittingEmptySubsequences: false)
        guard fields.count == 3, fields[0].count == 4, fields[1].count == 2, fields[2].count == 2,
              fields.allSatisfy({ field in field.allSatisfy { ("0"..."9").contains($0) } }),
              let year = Int(fields[0]), let month = Int(fields[1]), let dayOfMonth = Int(fields[2]) else { return nil }
        let calendar = dayCalendar(in: timeZone)
        guard let noon = calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: 12)) else {
            return nil
        }
        let start = calendar.startOfDay(for: noon)
        let named = calendar.dateComponents([.year, .month, .day], from: start)
        guard named.year == year, named.month == month, named.day == dayOfMonth else { return nil }
        return start
    }

    /// A Gregorian calendar in `timeZone`: the calendar a day's two conversions count in.
    private static func dayCalendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
