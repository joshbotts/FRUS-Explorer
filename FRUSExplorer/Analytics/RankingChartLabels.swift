// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Builds per-row y-axis labels for a horizontal ranking bar chart whose bars are keyed on each
/// row's **unique id** (not its display name), disambiguating rows that share a display name.
///
/// Analytics ranking charts (`CrossReferenceAnalyticsView` most-referenced documents,
/// `PersonAnalyticsView` most-mentioned people) must key their `BarMark` on a unique id, because
/// Swift Charts **sums** a bar's value across rows that share a categorical axis value — so keying
/// on a non-unique display name (a generic FRUS document title like "Department of State Minutes",
/// or a canonical person name shared by two unmerged rollups) silently merges distinct rows into
/// one oversized bar (#275 follow-up). Keying on the id fixes the bar geometry; this helper maps
/// each id back to a human axis label.
///
/// Labels are assigned so no two rows ever carry identical axis text:
///  1. a display name unique within the ranking is shown verbatim;
///  2. a shared display name gets its caller-supplied `shortSuffix` appended (e.g. the document id
///     or rollup id) — readable and usually sufficient;
///  3. in the rare case a `name · shortSuffix` is *still* shared (two rows with the same name and
///     short suffix, e.g. the same document id in different volumes), the row's guaranteed-unique
///     `id` is appended instead.
///
/// - Parameter rows: each ranked row's unique `id`, its `name` (the display label), and a
///   `shortSuffix` used to disambiguate a shared name.
/// - Returns: a map from row id to the label to render on the y-axis.
func disambiguatedRankingLabels(
    _ rows: [(id: String, name: String, shortSuffix: String)]
) -> [String: String] {
    var nameCounts: [String: Int] = [:]
    for row in rows { nameCounts[row.name, default: 0] += 1 }

    // First pass: bare name, or "name · shortSuffix" when the name is shared.
    var provisional: [String: String] = [:]
    var provisionalCounts: [String: Int] = [:]
    for row in rows {
        let label = (nameCounts[row.name] ?? 0) > 1 ? "\(row.name) · \(row.shortSuffix)" : row.name
        provisional[row.id] = label
        provisionalCounts[label, default: 0] += 1
    }

    // Second pass: if a "name · shortSuffix" is still shared, fall back to the unique id so no two
    // bars carry identical axis text.
    var labels: [String: String] = [:]
    for row in rows {
        let label = provisional[row.id] ?? row.name
        labels[row.id] = (provisionalCounts[label] ?? 0) > 1 ? "\(row.name) · \(row.id)" : label
    }
    return labels
}

// MARK: - Heat-matrix column codes

/// Builds compact, horizontal, collision-free **column codes** for the cross-volume citation heat
/// matrix (`CrossReferenceAnalyticsView`), so its column axis can read left-to-right inside a narrow
/// cell instead of a rotated, truncated volume id.
///
/// Each code is the volume's coverage span in apostrophe form plus a distinguisher:
///  - a volume's Roman numeral, taken **verbatim** from its manifest title — e.g. `'55–57 II`;
///  - or, when the title carries no "Volume <N>" numeral, its first distinctive topic word
///    truncated to ≤6 characters — e.g. `'58–60 Wester`;
///  - a bare span/year when neither is available (the early annual volumes) — e.g. `'63`.
///
/// Two columns whose base codes would collide are escalated: first by appending more topic words
/// (`'61–63 Berlin`), then — as a guaranteed-unique last resort — by appending the volume-id suffix
/// (`'63 p1` vs `'63 p2`), so no two columns ever render the same code. The full title still rides in
/// each label's `.help()`/VoiceOver text (supplied by the caller); this is only the visible glyph.
///
/// - Parameter columns: each column's stable `id` (e.g. `"frus1955-57v2"`), its `subseries` span
///   (`"1955-57"` or a single `"1861"`), the full manifest `title` (source of the Roman numeral),
///   and its distilled `topic` (empty for the early annual "Papers Relating…" volumes).
/// - Returns: a map from volume id to its rendered column code.
func matrixColumnCodes(
    _ columns: [(id: String, subseries: String, title: String, topic: String)]
) -> [String: String] {
    typealias Column = (id: String, subseries: String, title: String, topic: String)

    // Level-0 base code: span + (Roman numeral | first topic word | nothing).
    func base(_ c: Column) -> String {
        let years = matrixYearCode(c.subseries)
        if let numeral = firstVolumeNumeral(in: c.title) { return "\(years) \(numeral)" }
        if let word = matrixTopicWords(c.topic).first { return "\(years) \(String(word.prefix(6)))" }
        return years
    }
    // Escalated code: append the *next* distinctive token beyond what the base used, ≤6 chars so it
    // stays short enough for a narrow column. A numeral base ("years numeral") gains the first topic
    // word (two 1945 conference "Volume II"s → "'45 II Confer" / "'45 II Genera"); a topic-word base
    // ("years firstWord") gains the second topic word ("'58–60 Wester Europe" vs "…Hemisp").
    func expanded(_ c: Column) -> String {
        let years = matrixYearCode(c.subseries)
        let words = matrixTopicWords(c.topic)
        if let numeral = firstVolumeNumeral(in: c.title) {
            guard let first = words.first else { return "\(years) \(numeral)" }
            return "\(years) \(numeral) \(String(first.prefix(6)))"
        }
        var s = years
        if let first = words.first { s += " \(String(first.prefix(6)))" }
        if let second = words.dropFirst().first { s += " \(String(second.prefix(6)))" }
        return s
    }

    // Pass 1 — base codes.
    var baseCounts: [String: Int] = [:]
    let bases = columns.map { (id: $0.id, code: base($0)) }
    for b in bases { baseCounts[b.code, default: 0] += 1 }

    // Pass 2 — expand any shared base with topic words.
    var provisional: [String: String] = [:]
    var provisionalCounts: [String: Int] = [:]
    for (c, b) in zip(columns, bases) {
        let code = (baseCounts[b.code] ?? 0) > 1 ? expanded(c) : b.code
        provisional[c.id] = code
        provisionalCounts[code, default: 0] += 1
    }

    // Pass 3 — guaranteed-unique id-suffix fallback for anything still shared (e.g. two Part-only
    // annual volumes of the same year with no topic and no numeral).
    var result: [String: String] = [:]
    for c in columns {
        let code = provisional[c.id] ?? base(c)
        if (provisionalCounts[code] ?? 0) > 1 {
            var suffix = c.id
            if suffix.hasPrefix("frus") { suffix = String(suffix.dropFirst(4)) }
            if suffix.hasPrefix(c.subseries) { suffix = String(suffix.dropFirst(c.subseries.count)) }
            suffix = suffix.trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
            let years = matrixYearCode(c.subseries)
            result[c.id] = suffix.isEmpty ? years : "\(years) \(suffix)"
        } else {
            result[c.id] = code
        }
    }
    return result
}

/// The apostrophe-form coverage span for a subseries: `"1955-57"` → `"'55–57"`, `"1861"` → `"'61"`.
/// (Subseries spans use a hyphen with an already-2-digit end; the code uses an en-dash.)
private func matrixYearCode(_ subseries: String) -> String {
    // The elision mark is a RIGHT single quote (U+2019), matching the matrix caption in
    // `FRUSTheme` that explains these labels by example. A naive smart-quote pass turns a leading
    // `'` into a LEFT quote — `‘55` reads as an opening quotation mark, `’55` as the elided `19`.
    let parts = subseries.split(separator: "-", maxSplits: 1)
    if parts.count == 2 {
        return "\u{2019}\(parts[0].suffix(2))–\(parts[1].suffix(2))"
    }
    return "\u{2019}\(subseries.suffix(2))"
}

/// The first "Volume <roman>" numeral in a manifest title, verbatim (`"…, Volume II"` → `"II"`), or
/// `nil` when the title carries none (the early annual "Papers Relating…" volumes). Matches the
/// singular or plural token and captures the first Roman run only (`"Volumes II/III"` → `"II"`).
private func firstVolumeNumeral(in title: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: "Volumes?\\s+([IVXLCDM]+)\\b") else { return nil }
    let ns = title as NSString
    guard let m = regex.firstMatch(in: title, range: NSRange(location: 0, length: ns.length)),
          m.numberOfRanges > 1 else { return nil }
    return ns.substring(with: m.range(at: 1))
}

/// The distinctive words of a distilled topic — dropping leading articles/prepositions and any
/// trailing ellipsis — so the first word chosen for a column code is meaningful
/// (`"The Far East…"` → `["Far", "East"]`).
private func matrixTopicWords(_ topic: String) -> [String] {
    let stop: Set<String> = ["the", "of", "and", "to", "a", "an", "in", "on", "for"]
    let tokens = topic
        .replacingOccurrences(of: "…", with: " ")
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { $0.count >= 2 }
    return Array(tokens.drop { stop.contains($0.lowercased()) })
}
