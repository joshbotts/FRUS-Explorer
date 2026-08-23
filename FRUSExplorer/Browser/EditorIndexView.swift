// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI

// MARK: - EditorIndexGrouping

/// The Editors browse axis's pure logic (#1051 A-4, design 1h): name normalization, the
/// curated alias table, the inverted editor → volumes index, and the letter sections —
/// split from the view for testability (the Topic Index pattern).
///
/// ## The settled semantics this encodes (owner decision Q-1)
/// - **Compilers only.** `editors` is indexed; `generalEditor` is NOT — general editors
///   stay credited on each volume's own page. (This also keeps the one cross-surname
///   variant in the corpus, Nuermberger/Nuremberger, out of scope: the misspelling
///   occurs only in general-editor credits.)
/// - **Normalization lives HERE, in the grouping layer, never in the manifest.** The
///   citation formatters and exporters render the as-printed strings; rewriting them
///   would silently change every exported citation.
///
/// ## The two normalization layers
/// 1. **Mechanical** (`mechanicallyNormalized`): whitespace collapse, `"J ."` → `"J."`,
///    `"E.R."` → `"E. R."`, and a trailing-period strip that spares initials and
///    Jr./Sr. suffixes — this alone folds the punctuation variants
///    (`"E.R. Perkins"`, `"Robert J . McMahon"`, `"Henry P. Beers."`).
/// 2. **Curated aliases** (`aliases`): the measured spelling-variant clusters, folded to
///    the MOST FREQUENTLY PRINTED form (ties → the fuller form). Curated by hand and
///    reviewable in one sitting, because the obvious rule over-merges: Shirley L.
///    Phillips (23 volumes) and Steven E. Phillips (2) collide on surname + initial and
///    are two different historians — the pair is deliberately ABSENT from this table,
///    and a test pins that they stay separate rows.
///
/// Version history:
///   1.0 — #1051 B-2: initial implementation
enum EditorIndexGrouping {

    // MARK: Rows

    /// One editor in the index: the canonical name, the volumes naming them (in
    /// publication order), and how many printed spellings folded into the row.
    struct EditorRow: Identifiable {
        let name: String
        /// Member volume ids, publication year ascending (ties by volume id) — the
        /// order the drill states in its caption.
        let volumeIds: [String]
        /// Distinct printed spellings folded into this row (1 = printed one way).
        let variantCount: Int

        var id: String { name }
    }

    /// One letter section of the index.
    struct EditorSection: Identifiable {
        /// The surname initial ("A"–"Z", or "#" for anything else, sorted last).
        let letter: String
        let editors: [EditorRow]

        var id: String { letter }
    }

    // MARK: Normalization

    /// Suffix tokens that survive a trailing period and are skipped when finding the
    /// surname ("William F. Sanford, Jr." files under S).
    private static let suffixes: Set<String> = ["jr", "sr", "ii", "iii", "iv"]

    /// The mechanical cleanup: collapse whitespace, re-attach orphaned periods, split
    /// run-together initials, and strip a stray trailing period — sparing single-letter
    /// initials and Jr./Sr.-style suffixes.
    ///
    /// - Parameter raw: The as-printed name.
    /// - Returns: The mechanically normalized form.
    static func mechanicallyNormalized(_ raw: String) -> String {
        var name = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        // "Robert J . McMahon" → "Robert J. McMahon"
        name = name.replacingOccurrences(of: " .", with: ".")
        // "E.R. Perkins" → "E. R. Perkins" (insert a space between initial pairs)
        while let range = name.range(of: #"\b([A-Z])\.([A-Z])\."#, options: .regularExpression) {
            let pair = name[range]
            name.replaceSubrange(range, with: "\(pair.prefix(2)) \(pair.suffix(2))")
        }
        // "Henry P. Beers." → "Henry P. Beers" — but "…, Jr." and "N. O." keep theirs.
        if name.hasSuffix("."), let last = name.split(separator: " ").last {
            let bare = last.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if bare.count > 1, !suffixes.contains(bare.lowercased()) {
                name = String(name.dropLast())
            }
        }
        return name
    }

    /// The curated variant → canonical table (35 clusters, 39 rows), applied AFTER
    /// mechanical normalization. Canonical = the most frequently printed form, ties
    /// broken toward the fuller form — measured against the shipped manifest, not
    /// guessed. The Phillips pair is deliberately absent (two people; see the type doc).
    static let aliases: [String: String] = [
        "Fredrick Aandahl": "Frederick Aandahl",
        "Sara Berndt": "Sara E. Berndt",
        "Velma H. Cassidy": "Velma Hastings Cassidy",
        "Rogers Platt Churchill": "Rogers P. Churchill",
        "Bradley L. Coleman": "Bradley Lynn Coleman",
        "Evan Duncan": "Evan M. Duncan",
        "David I. Goldman": "David Goldman",
        "Ralph E. Goodwin": "Ralph R. Goodwin",
        "Paul Hibbeln": "Paul J. Hibbeln",
        "Susan Holly": "Susan K. Holly",
        "Nina D. Howland": "Nina Davis Howland",
        "Nina Howland": "Nina Davis Howland",
        "William Klingaman": "Will Klingaman",
        "William K. Klingaman": "Will Klingaman",
        "Peter Kraemer": "Peter A. Kraemer",
        "Shirley L. Landau": "Shirley F. Landau",
        "Daniel Lawler": "Daniel J. Lawler",
        "Joan Lee": "Joan M. Lee",
        "Erin Mahan": "Erin R. Mahan",
        "Richard B. McCornack": "Richard P. McCornack",
        "Robert McMahon": "Robert J. McMahon",
        "Aaron Miller": "Aaron D. Miller",
        "David Nickles": "David P. Nickles",
        "E. Ralph Perkins": "E. R. Perkins",
        "E. B. Perkins": "E. R. Perkins",
        "Neil H. Petersen": "Neal H. Petersen",
        "Linda W. Qaimmaqami": "Linda Qaimmaqami",
        "John Gilbert Reid": "John G. Reid",
        "Newton O. Sappington": "N. O. Sappington",
        "Harriet Dashiell Schwar": "Harriet D. Schwar",
        "James F. Siekmeier": "James Siekmeier",
        "William Slany": "William Z. Slany",
        "Howard M. Smyth": "Howard McGaw Smyth",
        "Ilana Stern": "Ilana M. Stern",
        "Sherrill Brown Wells": "Sherrill B. Wells",
        "Alexander Wieland": "Alexander R. Wieland",
        "Almon E. Wright": "Almon R. Wright",
        "Almon H. Wright": "Almon R. Wright",
        "Carolyn Yee": "Carolyn B. Yee",
    ]

    /// The canonical form of an as-printed editor credit.
    ///
    /// - Parameter raw: The name as the manifest carries it.
    /// - Returns: Mechanically normalized, then alias-folded.
    static func canonicalName(_ raw: String) -> String {
        let mechanical = mechanicallyNormalized(raw)
        return aliases[mechanical] ?? mechanical
    }

    /// The surname used for sorting and sectioning — the last token, skipping
    /// Jr./Sr.-style suffixes and trailing commas.
    ///
    /// - Parameter name: A canonical name.
    /// - Returns: The surname, or the whole name when tokenization fails.
    static func surname(of name: String) -> String {
        let tokens = name.split(separator: " ").map {
            $0.trimmingCharacters(in: CharacterSet(charactersIn: ",."))
        }
        for token in tokens.reversed() where !suffixes.contains(token.lowercased()) && !token.isEmpty {
            return token
        }
        return name
    }

    // MARK: Index building

    /// Builds the editor rows from the manifest: canonicalize every credit, invert to
    /// editor → volumes, order each row's volumes by publication year (ties by volume
    /// id), and count the distinct printed spellings that folded in.
    ///
    /// - Parameter entries: The volume universe.
    /// - Returns: The rows, sorted by surname then full name.
    static func rows(from entries: [VolumeManifestEntry]) -> [EditorRow] {
        struct Accumulator {
            var volumes: [VolumeManifestEntry] = []
            var spellings: Set<String> = []
        }
        var byEditor: [String: Accumulator] = [:]
        for entry in entries {
            for raw in entry.editors {
                let canonical = canonicalName(raw)
                guard !canonical.isEmpty else { continue }
                var acc = byEditor[canonical] ?? Accumulator()
                if !acc.volumes.contains(where: { $0.volumeId == entry.volumeId }) {
                    acc.volumes.append(entry)
                }
                acc.spellings.insert(raw)
                byEditor[canonical] = acc
            }
        }
        return byEditor
            .map { name, acc -> EditorRow in
                let ordered = acc.volumes.sorted {
                    let a = VolumeCatalogueGrouping.publicationYear(of: $0) ?? Int.max
                    let b = VolumeCatalogueGrouping.publicationYear(of: $1) ?? Int.max
                    if a != b { return a < b }
                    return $0.volumeId < $1.volumeId
                }
                return EditorRow(name: name,
                                 volumeIds: ordered.map(\.volumeId),
                                 variantCount: acc.spellings.count)
            }
            .sorted {
                let cmp = surname(of: $0.name).localizedCaseInsensitiveCompare(surname(of: $1.name))
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    /// Letter sections over the rows, filtered by a query matching the name.
    ///
    /// - Parameters:
    ///   - rows: The full row set from `rows(from:)`.
    ///   - query: The search text; empty shows everything.
    /// - Returns: Sections "A"–"Z" in order, "#" last.
    static func sections(from rows: [EditorRow], query: String) -> [EditorSection] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.isEmpty ? rows : rows.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
        guard !filtered.isEmpty else { return [] }
        var buckets: [String: [EditorRow]] = [:]
        var order: [String] = []
        for row in filtered {
            let initial = surname(of: row.name).first
            let letter = (initial?.isLetter == true) ? String(initial!).uppercased() : "#"
            if buckets[letter] == nil { order.append(letter) }
            buckets[letter, default: []].append(row)
        }
        let sorted = order.sorted {
            if $0 == "#" { return false }
            if $1 == "#" { return true }
            return $0 < $1
        }
        return sorted.map { EditorSection(letter: $0, editors: buckets[$0] ?? []) }
    }

    /// The R-1 drill spec for one editor.
    ///
    /// - Parameter row: The editor row.
    /// - Returns: The spec — ids in publication order, with the caption saying so.
    static func spec(for row: EditorRow) -> VolumeListSpec {
        VolumeListSpec(
            axisKey: "editor:\(row.name)",
            title: row.name,
            volumeIds: row.volumeIds,
            caption: String(
                localized: "browser.editors.drill.caption",
                defaultValue: "\(row.volumeIds.count) volumes naming \(row.name) as a volume editor, in publication order. Editor credits are shown as printed on each title page.")
        )
    }
}

// MARK: - EditorIndexView

/// The Editors index (#1051 A-4, design 1h): every volume editor — compilers, not the
/// general editor — letter-sectioned by surname, searchable, drilling to the R-1 list.
///
/// Shared across both platforms behind one `onSelect` closure (the catalogue's pattern).
///
/// Version history:
///   1.0 — #1051 B-2: initial implementation
struct EditorIndexView: View {

    /// The volume universe (the manifest's browsable entries).
    let entries: [VolumeManifestEntry]
    /// Row action — the mount's navigation, handed the ready-built drill spec.
    let onSelect: @MainActor (VolumeListSpec) -> Void

    /// The rows, built once per appearance — canonicalizing 552 entries is cheap but is
    /// not work for `body`.
    @State private var rows: [EditorIndexGrouping.EditorRow] = []
    @State private var query = ""

    var body: some View {
        List {
            Section {
                Text(coverageCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(EditorIndexGrouping.sections(from: rows, query: query)) { section in
                Section(section.letter) {
                    ForEach(section.editors) { row in
                        Button {
                            onSelect(EditorIndexGrouping.spec(for: row))
                            #if DEBUG
                            print("[EditorIndexView] Navigate → \(row.name)")
                            #endif
                        } label: {
                            rowLabel(row)
                                // Both modifiers, in this order — the #312 idiom.
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            String(localized: "browser.editors.row.a11y",
                                   defaultValue: "\(row.name), \(row.volumeIds.count) volumes")
                        )
                        .help(String(localized: "browser.editors.row.help",
                                     defaultValue: "Browse the volumes this editor compiled"))
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .searchable(text: $query,
                    prompt: Text(String(localized: "browser.editors.search.prompt",
                                        defaultValue: "Search editors")))
        .navigationTitle(String(localized: "browser.editors.title", defaultValue: "Editors"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { rows = EditorIndexGrouping.rows(from: entries) }
    }

    /// The honesty caption: whose names these are, and the corpus's structural gap —
    /// counts computed live from the manifest, never hard-coded.
    private var coverageCaption: String {
        let named = entries.filter { !$0.editors.isEmpty }.count
        let none = entries.count - named
        return String(
            localized: "browser.editors.coverage",
            defaultValue: "Volume editors as named on each title page. \(named) of \(entries.count) volumes name editors — \(none) early volumes carry none, so this index cannot reach them. General editors are credited on the volume page, not indexed here.")
    }

    @ViewBuilder
    private func rowLabel(_ row: EditorIndexGrouping.EditorRow) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.body)
                if row.variantCount > 1 {
                    Text(String(localized: "browser.editors.variants",
                                defaultValue: "\(row.variantCount) spellings merged"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
            Text(String(localized: "browser.editors.row.volumes",
                        defaultValue: "\(row.volumeIds.count) volumes"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - BrowseEditorsLevel (iOS mount)

#if os(iOS)

/// The iOS mount: `BrowserLevel.editors`; a row pushes the ready-built R-1 spec.
///
/// Version history:
///   1.0 — #1051 B-2: initial implementation
struct BrowseEditorsLevel: View {
    let vm: BrowserViewModel

    var body: some View {
        EditorIndexView(
            entries: vm.allVolumes,
            onSelect: { [vm] spec in
                vm.navigationPath.append(.volumeList(spec))
            }
        )
    }
}

#endif // os(iOS)
