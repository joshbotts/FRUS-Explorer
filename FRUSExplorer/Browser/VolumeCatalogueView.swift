// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - VolumeCatalogueGrouping

/// The All Volumes catalogue's pure presentation logic (#1051 A-1/A-2, design 1e):
/// query filtering, the four sort modes, and the section building — split from the view
/// for testability, the Topic Index (`SubjectIndexGrouping`) pattern.
///
/// ## The two data truths this encodes
/// - **Naive alphabetical title sort is degenerate**: 409 of 552 titles begin "Foreign
///   Relations of the United States" and 142 begin "Papers Relating…", so the Title mode
///   files by the DISTINCTIVE segment (`distinctiveTitleKey`) — the part after the volume
///   designator, or after the boilerplate + year for older forms.
/// - **`publicationDate` is a free-form string** (551 bare "YYYY" + one full ISO date), so
///   the Published mode parses through `FRUSVolumeMetadata.firstYear(in:)`, never string
///   sort. And it is the PRINT year — the axis is labelled "publication year", never
///   release/declassification semantics.
///
/// Version history:
///   1.0 — #1051 B-1: initial implementation
enum VolumeCatalogueGrouping {

    /// The catalogue's four presentations.
    enum SortMode: String, CaseIterable, Identifiable {
        case title, published, era, length

        var id: String { rawValue }

        /// The segmented control's label.
        var label: String {
            switch self {
            case .title:
                return String(localized: "browser.catalogue.mode.title", defaultValue: "Title")
            case .published:
                return String(localized: "browser.catalogue.mode.published", defaultValue: "Published")
            case .era:
                return String(localized: "browser.catalogue.mode.era", defaultValue: "Era")
            case .length:
                return String(localized: "browser.catalogue.mode.length", defaultValue: "Length")
            }
        }
    }

    /// One rendered section: an optional header plus its entries, ordered.
    struct CatalogueSection: Identifiable {
        let id: String
        /// The section header, or `nil` for a headerless run (the Length mode).
        let title: String?
        let entries: [VolumeManifestEntry]
    }

    // MARK: Title keys

    /// The boilerplate prefixes, longest first — "Papers Relating…" contains the shorter
    /// "Foreign Relations…" as a substring, so order matters.
    private static let boilerplatePrefixes = [
        "Papers Relating to the Foreign Relations of the United States",
        "Foreign Relations of the United States",
    ]

    /// The distinctive segment of a volume title — what the Title mode files and shows.
    ///
    /// "Foreign Relations of the United States, 1969–1976, Volume XVII, China, 1969–1972"
    /// → "China, 1969–1972"; "…, 1949, The Far East: China, Volume IX" → "The Far East:
    /// China"; "Papers Relating to …, 1894" → "1894" (filed under "#"). Never empty: when
    /// stripping consumes everything, the full title is returned unchanged.
    ///
    /// - Parameter title: The whitespace-normalized manifest title.
    /// - Returns: The distinctive segment.
    static func distinctiveTitleKey(_ title: String) -> String {
        var s = Substring(title)

        // 1. Strip the series boilerplate.
        for prefix in boilerplatePrefixes where s.hasPrefix(prefix) {
            s = s.dropFirst(prefix.count)
            break
        }
        s = trimSeparators(s)

        // 2. Drop a leading coverage-year segment ("1949, " / "1969–1976, ") — but never
        //    when it is the whole remainder (the early annuals' only distinctive part).
        if let comma = s.range(of: ", ") {
            let first = s[..<comma.lowerBound]
            if !first.isEmpty, first.allSatisfy({ $0.isNumber || "–—-".contains($0) }) {
                s = s[comma.upperBound...]
            }
        }

        // 3. Drop leading "Volume XVII, " and "Part 1, " designators.
        for designator in ["Volume ", "Volumes ", "Part "] {
            while s.hasPrefix(designator), let comma = s.range(of: ", ") {
                s = s[comma.upperBound...]
            }
        }

        // 4. Drop a TRAILING ", Volume IX" designator (the pre-war forms put the subject
        //    before the volume number) — only when nothing follows it.
        if let volRange = s.range(of: ", Volume ", options: .backwards) {
            let after = s[volRange.upperBound...]
            if !after.contains(", ") {
                s = s[..<volRange.lowerBound]
            }
        }

        let trimmed = trimSeparators(s)
        return trimmed.isEmpty ? title : String(trimmed)
    }

    /// The A–Z index bucket for a distinctive key: its first letter, or `"#"` for digits
    /// and anything else. `"#"` sorts last (the `SubjectIndexGrouping` convention).
    ///
    /// - Parameter key: A `distinctiveTitleKey` result.
    /// - Returns: `"A"`…`"Z"` or `"#"`.
    static func titleBucket(forKey key: String) -> String {
        guard let first = key.first, first.isLetter else { return "#" }
        return String(first).uppercased()
    }

    private static func trimSeparators(_ s: Substring) -> Substring {
        var out = s
        let separators: Set<Character> = [" ", ",", ";", ":", "—", "–", "-", "\n", "\t"]
        while let f = out.first, separators.contains(f) { out = out.dropFirst() }
        while let l = out.last, separators.contains(l) { out = out.dropLast() }
        return out
    }

    // MARK: Years

    /// The volume's print year, parsed leniently — 551 entries are bare "YYYY" and exactly
    /// one is a full ISO date, so this goes through `firstYear(in:)`, never string sort.
    ///
    /// - Parameter entry: The manifest entry.
    /// - Returns: The 4-digit print year, or `nil`.
    static func publicationYear(of entry: VolumeManifestEntry) -> Int? {
        FRUSVolumeMetadata.firstYear(in: entry.publicationDate)
    }

    /// Every 4-digit run in a subseries string ("1969-76" → [1969]; "1981–1988" →
    /// [1981, 1988]). Used by the corpus root's Subseries-tile caption; it lives HERE and
    /// not on the view because a `View`'s statics are MainActor-isolated and a helper
    /// parked there crashes any nonisolated test that calls it.
    ///
    /// - Parameter string: The subseries identifier.
    /// - Returns: Each 4-digit number found, in order.
    static func fourDigitRuns(in string: String) -> [Int] {
        string.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted)
            .filter { $0.count == 4 }
            .compactMap { Int($0) }
    }

    // MARK: Sections

    /// Builds the catalogue's sections for one mode and query.
    ///
    /// The query matches title and volume id, case-insensitively. Ordering rules per mode:
    /// - `.title`: A–Z by distinctive key (case-insensitive), tie-broken by volumeId;
    ///   sections lettered with `"#"` last.
    /// - `.published`: print year DESCENDING, tie-broken by volumeId; decade sections
    ///   ("2020s"…); entries with no parseable year land in a trailing section.
    /// - `.era`: the subseries grouping, newest first (the directory's own order); entries
    ///   in manifest order within each.
    /// - `.length`: document count DESCENDING (tie-broken by volumeId; unknown counts
    ///   last), one headerless section.
    ///
    /// - Parameters:
    ///   - entries: The volume universe, in manifest order.
    ///   - mode: The presentation.
    ///   - query: The search text (trimmed by the caller or not — matching trims nothing).
    ///   - documentCount: The R-2 accessor (used by `.length` only).
    /// - Returns: The ordered sections.
    ///
    /// `@MainActor` only because the accessor closes over a main-actor store; the logic
    /// itself is pure and state-free (tests annotate themselves rather than lose this).
    @MainActor
    static func sections(
        entries: [VolumeManifestEntry],
        mode: SortMode,
        query: String,
        documentCount: @MainActor (String) -> Int?
    ) -> [CatalogueSection] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmedQuery.isEmpty ? entries : entries.filter {
            $0.title.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.volumeId.localizedCaseInsensitiveContains(trimmedQuery)
        }
        guard !filtered.isEmpty else { return [] }

        switch mode {
        case .title:
            let keyed = filtered
                .map { (key: distinctiveTitleKey($0.title), entry: $0) }
                .sorted {
                    let cmp = $0.key.localizedCaseInsensitiveCompare($1.key)
                    if cmp != .orderedSame { return cmp == .orderedAscending }
                    return $0.entry.volumeId < $1.entry.volumeId
                }
            var buckets: [String: [VolumeManifestEntry]] = [:]
            var order: [String] = []
            for item in keyed {
                let bucket = titleBucket(forKey: item.key)
                if buckets[bucket] == nil { order.append(bucket) }
                buckets[bucket, default: []].append(item.entry)
            }
            // Letters A–Z, then "#": the keyed sort already yields that order except that
            // digit-keyed entries sort BEFORE letters under localized comparison.
            let sortedBuckets = order.sorted {
                if $0 == "#" { return false }
                if $1 == "#" { return true }
                return $0 < $1
            }
            return sortedBuckets.map { CatalogueSection(id: "title-\($0)", title: $0, entries: buckets[$0] ?? []) }

        case .published:
            let dated = filtered.compactMap { entry -> (year: Int, entry: VolumeManifestEntry)? in
                guard let year = publicationYear(of: entry) else { return nil }
                return (year, entry)
            }.sorted {
                if $0.year != $1.year { return $0.year > $1.year }
                return $0.entry.volumeId < $1.entry.volumeId
            }
            let undated = filtered.filter { publicationYear(of: $0) == nil }
                .sorted { $0.volumeId < $1.volumeId }
            var sections: [CatalogueSection] = []
            var currentDecade: Int? = nil
            var bucket: [VolumeManifestEntry] = []
            func flush() {
                guard let decade = currentDecade, !bucket.isEmpty else { return }
                sections.append(CatalogueSection(id: "decade-\(decade)", title: "\(decade)s", entries: bucket))
                bucket = []
            }
            for item in dated {
                let decade = (item.year / 10) * 10
                if decade != currentDecade {
                    flush()
                    currentDecade = decade
                }
                bucket.append(item.entry)
            }
            flush()
            if !undated.isEmpty {
                sections.append(CatalogueSection(
                    id: "undated",
                    title: String(localized: "browser.catalogue.noYear", defaultValue: "No publication year"),
                    entries: undated
                ))
            }
            return sections

        case .era:
            var groups: [String: [VolumeManifestEntry]] = [:]
            for entry in filtered { groups[entry.subseries, default: []].append(entry) }
            let ordered = groups.keys.sorted {
                let a = Int($0.prefix(4)) ?? 0
                let b = Int($1.prefix(4)) ?? 0
                if a != b { return a > b }
                return $0 < $1
            }
            return ordered.map { CatalogueSection(id: "era-\($0)", title: $0, entries: groups[$0] ?? []) }

        case .length:
            let sorted = filtered.sorted {
                let a = documentCount($0.volumeId)
                let b = documentCount($1.volumeId)
                switch (a, b) {
                case (let x?, let y?):
                    if x != y { return x > y }
                    return $0.volumeId < $1.volumeId
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return $0.volumeId < $1.volumeId
                }
            }
            return [CatalogueSection(id: "length", title: nil, entries: sorted)]
        }
    }
}

// MARK: - VolumeCatalogueStatus

/// A volume row's device-state flags — computed by the mount, so the shared view stays
/// platform- and store-agnostic.
struct VolumeCatalogueStatus {
    let isDownloaded: Bool
    let isIndexed: Bool
    let isDownloading: Bool
}

// MARK: - VolumeCatalogueView

/// The All Volumes catalogue (#1051 A-1/A-2, design 1e): every volume under one level,
/// searchable, with the Title / Published / Era / Length segmented presentations.
///
/// Shared across both platforms — the mounts differ only in the closures: the iOS level
/// (`BrowseCatalogueLevel`) appends `.volume` to the Browse path; the macOS Corpus Browser
/// pushes `CorpusNavValue.volume` in its detail column. Uses native `.searchable`: this is
/// a pushed level (iOS) / detail-column root (macOS), where exactly one search source is
/// attached (the corpus ROOT uses an inline field for precisely this reason).
///
/// Version history:
///   1.0 — #1051 B-1: initial implementation
struct VolumeCatalogueView: View {

    /// The volume universe, in manifest order.
    let entries: [VolumeManifestEntry]
    /// The R-2 document-count accessor. `@MainActor` because the mounts close over
    /// main-actor stores and the view only calls it from `body`.
    let documentCount: @MainActor (String) -> Int?
    /// Device-state flags per volume id (same isolation rationale).
    let status: @MainActor (String) -> VolumeCatalogueStatus
    /// Row action — the mount's navigation (same isolation rationale).
    let onSelect: @MainActor (VolumeManifestEntry) -> Void

    /// The selected presentation, device-local and persistent (decision register:
    /// device-local browse state lives in UserDefaults, never on a synced model).
    @AppStorage("browse.catalogue.sortMode")
    private var sortModeRaw: String = VolumeCatalogueGrouping.SortMode.published.rawValue

    @State private var query = ""

    private var sortMode: VolumeCatalogueGrouping.SortMode {
        VolumeCatalogueGrouping.SortMode(rawValue: sortModeRaw) ?? .published
    }

    var body: some View {
        List {
            controlSection

            ForEach(VolumeCatalogueGrouping.sections(
                entries: entries, mode: sortMode, query: query, documentCount: documentCount
            )) { section in
                if let title = section.title {
                    Section(title) { rows(for: section) }
                } else {
                    Section { rows(for: section) }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .searchable(text: $query,
                    prompt: Text(String(localized: "browser.catalogue.search.prompt",
                                        defaultValue: "Title or volume number")))
        .navigationTitle(String(localized: "browser.catalogue.title", defaultValue: "All Volumes"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// The segmented mode picker and the coverage caption, pinned above the rows.
    private var controlSection: some View {
        Section {
            Picker(String(localized: "browser.catalogue.mode.picker", defaultValue: "Arrange by"),
                   selection: $sortModeRaw) {
                ForEach(VolumeCatalogueGrouping.SortMode.allCases) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Above the rows, not in a footer — a caveat below 552 rows cannot do its job
            // (the Topic Index pattern). "Publication year" is the print year, deliberately:
            // promising release/declassification semantics would be a false-premise repeat.
            Text(String(localized: "browser.catalogue.coverage",
                        defaultValue: "\(entries.count) volumes. Publication year is the print year. Document counts are FRUS document divs from the bundled index; Search over the same volume can return more rows."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func rows(for section: VolumeCatalogueGrouping.CatalogueSection) -> some View {
        ForEach(section.entries) { entry in
            Button {
                onSelect(entry)
            } label: {
                rowLabel(for: entry)
                    // Both modifiers, in this order — the #312 full-row tap-target idiom.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func rowLabel(for entry: VolumeManifestEntry) -> some View {
        let state = status(entry.volumeId)
        if sortMode == .title {
            // Title mode files by the distinctive segment, so the row LEADS with it —
            // 552 rows starting "Foreign Relations of the United States" cannot be scanned.
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(VolumeCatalogueGrouping.distinctiveTitleKey(entry.title))
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if state.isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .accessibilityLabel(
                                String(localized: "browser.volume.downloaded.a11y",
                                       defaultValue: "Downloaded")
                            )
                    }
                }
                HStack(spacing: 6) {
                    Text(entry.title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let year = VolumeCatalogueGrouping.publicationYear(of: entry) {
                        Text("· \(String(year))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)
        } else {
            VolumeRowLabel(
                volume: entry,
                isDownloaded: state.isDownloaded,
                isIndexed: state.isIndexed,
                isDownloading: state.isDownloading,
                documentCount: documentCount(entry.volumeId)
            )
        }
    }
}

// MARK: - BrowseCatalogueLevel (iOS mount)

#if os(iOS)

/// The iOS mount of the catalogue: `BrowserLevel.catalogue`, wired to the Browse view
/// model and the R-2 accessor. Rows APPEND `.volume` — this is a pushed level, and Back
/// must return to the catalogue.
///
/// Version history:
///   1.0 — #1051 B-1: initial implementation
struct BrowseCatalogueLevel: View {
    let vm: BrowserViewModel

    @Environment(AppState.self) private var appState

    var body: some View {
        VolumeCatalogueView(
            entries: vm.allVolumes,
            documentCount: { [store = appState.administrationProfilesStore] id in
                store.documentCount(forVolumeId: id)
            },
            status: { [vm, appState] id in
                VolumeCatalogueStatus(
                    isDownloaded: vm.isDownloaded(id),
                    isIndexed: vm.isIndexed(id),
                    isDownloading: appState.downloadQueue.contains(id)
                )
            },
            onSelect: { [vm] entry in
                vm.navigationPath.append(.volume(entry))
                #if DEBUG
                print("[BrowserView] Catalogue → volume \(entry.volumeId)")
                #endif
            }
        )
    }
}

#endif // os(iOS)
