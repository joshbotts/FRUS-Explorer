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
