// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SeriesScope

/// A subseries scope for the "About the Series" analytics dashboards (#236): a set of
/// manifest volume ids to restrict a dashboard to, or `nil` for the whole series.
///
/// Deliberately distinct from corpus analytics' `AnalyticsScopeBar`, which scopes over
/// the user's *indexed* FTS volumes via `CorpusAnalyticsService`. The Series dashboards
/// derive from the bundled manifest and must render zero-index (mid-onboarding), so their
/// scope is over manifest entries and carries no service dependency.
struct SeriesScope: Sendable, Equatable {
    /// The in-scope volume ids, or `nil` for the whole series.
    var volumeIds: Set<String>?
    /// A human-readable label for the active scope (the subseries name), or `nil`.
    var label: String?

    /// The whole-series scope.
    static let whole = SeriesScope(volumeIds: nil, label: nil)

    /// `true` when a subseries (or any subset) is active.
    var isNarrowed: Bool { volumeIds != nil }

    /// Whether a volume is in scope (always `true` for the whole-series scope).
    ///
    /// - Parameter volumeId: The volume id to test.
    /// - Returns: `true` when the volume should be included.
    func contains(_ volumeId: String) -> Bool {
        volumeIds?.contains(volumeId) ?? true
    }

    /// Filters manifest entries to those in scope (identity for the whole-series scope).
    ///
    /// - Parameter entries: The manifest entries to filter.
    /// - Returns: The in-scope entries, order preserved.
    func filter(_ entries: [VolumeManifestEntry]) -> [VolumeManifestEntry] {
        guard let ids = volumeIds else { return entries }
        return entries.filter { ids.contains($0.volumeId) }
    }
}

// MARK: - SeriesScopeBar

/// A "Scope: Whole series / By Subseries" selector for the Series-analytics dashboards
/// (#236), sharing `AnalyticsScopeBar`'s visual language but scoping over **manifest**
/// entries rather than indexed volumes.
///
/// Volume-level scope is deliberately omitted: a single volume yields a degenerate
/// series chart (one point / one bar) and the manifest's ~552 volumes would make a
/// giant nested menu. The per-volume story is already told by SA-2b's detail volume list.
///
/// The parent owns the `SeriesScope` as a binding and supplies the manifest entries to
/// derive subseries buckets from; the scope resets per-visit (`@State`, not persisted),
/// because these dashboards are an educational "About the Series" narrative and silently
/// re-opening on a stale narrowed scope would misrepresent the series.
///
/// Version history:
///   1.0 — Session 3 / #236: subseries scope for the Series dashboards
struct SeriesScopeBar: View {

    /// The manifest entries the dashboard summarises — the source of the subseries buckets.
    let entries: [VolumeManifestEntry]
    /// The active scope. `nil` volumeIds means the whole series.
    @Binding var scope: SeriesScope
    /// Invoked after the scope changes so the host can rebuild its derived data.
    var onChange: () -> Void = {}

    /// One subseries' menu entry: its display name and member volume ids.
    private struct SubseriesBucket {
        /// The subseries identifier (e.g. `"1969-76"` or `"1861"`).
        let subseries: String
        /// The volume ids belonging to the subseries.
        let volumeIds: Set<String>
    }

    /// One decade's submenu: the label (e.g. `"1860s"`) and its subseries, sorted.
    private struct DecadeGroup {
        /// The decade's leading year (e.g. `1860`), the sort key.
        let decade: Int
        /// The subseries whose leading year falls in this decade.
        let buckets: [SubseriesBucket]
        /// The submenu label (e.g. `"1860s"`).
        var label: String { "\(decade)s" }
    }

    /// The manifest's subseries grouped by the **decade of their leading year** — the
    /// manifest carries ~107 distinct subseries (the early annual volumes each use their
    /// year, e.g. `"1861"`), and a flat submenu of 107 items is unusable (verified live).
    /// Decade nesting yields ~14 submenus of at most a dozen entries each.
    private var decadeGroups: [DecadeGroup] {
        var byName: [String: Set<String>] = [:]
        for entry in entries where !entry.subseries.isEmpty {
            byName[entry.subseries, default: []].insert(entry.volumeId)
        }
        var byDecade: [Int: [SubseriesBucket]] = [:]
        for (name, ids) in byName {
            let leadingYear = Int(name.prefix(4)) ?? 0
            let decade = (leadingYear / 10) * 10
            byDecade[decade, default: []].append(SubseriesBucket(subseries: name, volumeIds: ids))
        }
        return byDecade
            .map { DecadeGroup(decade: $0.key, buckets: $0.value.sorted { $0.subseries < $1.subseries }) }
            .sorted { $0.decade < $1.decade }
    }

    /// The label shown in the menu button for the active scope.
    private var currentLabel: String {
        scope.label ?? String(localized: "series.scope.wholeSeries", defaultValue: "Whole series")
    }

    /// Applies a new scope and notifies the host.
    private func setScope(_ newScope: SeriesScope) {
        scope = newScope
        onChange()
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .foregroundStyle(.secondary)
                .font(.caption)
            Menu {
                Button {
                    setScope(.whole)
                } label: {
                    Label(String(localized: "series.scope.wholeSeries", defaultValue: "Whole series"),
                          systemImage: scope.isNarrowed ? "globe" : "checkmark")
                }
                let groups = decadeGroups
                if !groups.isEmpty {
                    Divider()
                    Menu(String(localized: "series.scope.bySubseries", defaultValue: "By Subseries")) {
                        ForEach(groups, id: \.decade) { group in
                            Menu(group.label) {
                                ForEach(group.buckets, id: \.subseries) { bucket in
                                    Button {
                                        setScope(SeriesScope(volumeIds: bucket.volumeIds, label: bucket.subseries))
                                    } label: {
                                        if scope.label == bucket.subseries {
                                            Label(bucket.subseries, systemImage: "checkmark")
                                        } else {
                                            Text(bucket.subseries)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(String(format: String(localized: "series.scope.label %@",
                                                defaultValue: "Scope: %@"), currentLabel))
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
            }
            .accessibilityLabel(String(localized: "series.scope.menu.a11y",
                                       defaultValue: "Analysis scope"))
            .accessibilityValue(currentLabel)
            Spacer()
            if scope.isNarrowed {
                Button {
                    setScope(.whole)
                } label: {
                    Text(String(localized: "series.scope.reset", defaultValue: "Whole series"))
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "series.scope.reset.a11y",
                                           defaultValue: "Reset scope to the whole series"))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
